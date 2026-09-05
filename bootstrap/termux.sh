#!/bin/sh
# shellcheck disable=SC2154 # sourced by init, which defines shared paths

# Sourced by ./init after platform detection. Keep this file POSIX sh compatible.

termux_link_config()
{
  termux_link_source=$1
  termux_link_target=$2
  mkdir -p "$(dirname "$termux_link_target")"
  if [ -L "$termux_link_target" ]; then
    rm -f "$termux_link_target"
  elif [ -e "$termux_link_target" ]; then
    if [ -e "$termux_link_target.pre-dotfiles" ]; then
      printf 'termux: preserving existing %s; configure it manually\n' "$termux_link_target" >&2
      return
    fi
    mv "$termux_link_target" "$termux_link_target.pre-dotfiles"
  fi
  ln -s "$termux_link_source" "$termux_link_target"
}

install_termux_core_packages()
{
  command -v pkg >/dev/null 2>&1 || {
    printf '%s\n' 'termux: pkg is unavailable; this setup must run inside Termux' >&2
    return 1
  }

  printf '%s\n' 'Updating Termux packages and installing the core CLI environment...'
  pkg update -y
  pkg install -y \
    ca-certificates curl diff-so-fancy fd file fzf git jq krb5 less nano \
    openssh python ripgrep rsync rust starship termux-api termux-services tig tmux tree unzip \
    vim which zip zoxide zsh
}

termux_shell_setup()
{
  termux_link_config "$config_dir/termux/.zshenv" "$HOME/.zshenv"
  termux_link_config "$config_dir/termux/termux.properties" "$HOME/.termux/termux.properties"
  termux_link_config "$config_dir/termux/colors.properties" "$HOME/.termux/colors.properties"

  if command -v termux-reload-settings >/dev/null 2>&1; then
    termux-reload-settings
  fi
}

termux_ssh_setup()
{
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519"
  fi

  sv-enable sshd
  sv-enable ssh-agent
}

termux_workbench_default_node_id()
{
  termux_model=$(getprop ro.product.model 2>/dev/null || printf '%s' termux)
  termux_model=$(printf '%s' "$termux_model" |
    tr '[:upper:]' '[:lower:]' |
    sed 's/[^a-z0-9._-][^a-z0-9._-]*/-/g; s/^-//; s/-$//')
  [ -n "$termux_model" ] || termux_model=termux
  printf '%s-termux\n' "$termux_model"
}

termux_workbench_local_config()
{
  termux_workbench_config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}/distributed-workbench
  termux_workbench_config=$termux_workbench_config_home/termux-peer.conf
  if [ -f "$termux_workbench_config" ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    printf '%s\n' \
      "termux: skipping distributed-workbench peer setup; create $termux_workbench_config or run ./init core interactively" >&2
    return 1
  fi

  printf '%s' 'SSH alias for the workbench node (empty to skip): '
  IFS= read -r termux_workbench_host
  [ -n "$termux_workbench_host" ] || return 1
  case $termux_workbench_host in
    *[!0-9A-Za-z._-]*)
      printf 'termux: invalid SSH alias: %s\n' "$termux_workbench_host" >&2
      return 1
      ;;
  esac
  termux_workbench_node_id=$(termux_workbench_default_node_id)
  mkdir -p "$termux_workbench_config_home"
  umask 077
  {
    printf 'DISTRIBUTED_WORKBENCH_PEER_HOST=%s\n' "$termux_workbench_host"
    printf 'DISTRIBUTED_WORKBENCH_TERMUX_NODE_ID=%s\n' "$termux_workbench_node_id"
    printf '%s\n' 'DISTRIBUTED_WORKBENCH_VERSION=latest'
  } >"$termux_workbench_config"
  chmod 600 "$termux_workbench_config"
}

termux_distributed_workbench_setup()
{
  termux_workbench_local_config || return 0
  termux_workbench_host=$(sed -n 's/^DISTRIBUTED_WORKBENCH_PEER_HOST=//p' "$termux_workbench_config" | tail -1)
  termux_workbench_node_id=$(sed -n 's/^DISTRIBUTED_WORKBENCH_TERMUX_NODE_ID=//p' "$termux_workbench_config" | tail -1)
  termux_workbench_version=$(sed -n 's/^DISTRIBUTED_WORKBENCH_VERSION=//p' "$termux_workbench_config" | tail -1)
  termux_workbench_version=${termux_workbench_version:-latest}
  for termux_workbench_value in "$termux_workbench_host" "$termux_workbench_node_id" "$termux_workbench_version"; do
    case $termux_workbench_value in
      ''|*[!0-9A-Za-z._-]*)
        printf 'termux: invalid value in %s\n' "$termux_workbench_config" >&2
        return 2
        ;;
    esac
  done

  if ! ssh -o BatchMode=yes -o ClearAllForwardings=yes "$termux_workbench_host" true; then
    printf 'termux: SSH alias %s is not ready; distributed-workbench setup deferred\n' "$termux_workbench_host" >&2
    return 0
  fi

  termux_workbench_cache=${XDG_CACHE_HOME:-"$HOME/.cache"}/distributed-workbench
  termux_workbench_installer=$termux_workbench_cache/install-from-release.sh
  mkdir -p "$termux_workbench_cache"
  curl -fsSL \
    https://raw.githubusercontent.com/lukewang1024/distributed-workbench/main/scripts/install-from-release.sh \
    -o "$termux_workbench_installer"
  chmod 755 "$termux_workbench_installer"
  if ! DISTRIBUTED_WORKBENCH_CONTROLLER_ID=$termux_workbench_node_id \
    DISTRIBUTED_WORKBENCH_EXECUTOR_ID=$termux_workbench_node_id-rust \
    "$termux_workbench_installer" "$termux_workbench_version" "$HOME"; then
    printf '%s\n' 'termux: published Android release unavailable; trying the authenticated peer bootstrap cache' >&2
    termux_workbench_remote_version_output=$(ssh -o BatchMode=yes -o ClearAllForwardings=yes \
      "$termux_workbench_host" '"$HOME/.local/bin/workbench" --version') || {
      printf '%s\n' 'termux: could not read distributed-workbench version from peer' >&2
      return 1
    }
    termux_workbench_remote_version=$(printf '%s\n' "$termux_workbench_remote_version_output" |
      awk 'NR == 1 {print $2}')
    case $termux_workbench_remote_version in
      ''|*[!0-9A-Za-z._-]*)
        printf '%s\n' 'termux: peer returned an invalid distributed-workbench version' >&2
        return 1
        ;;
    esac
    termux_workbench_archive=$termux_workbench_cache/termux-current.tar.gz
    ssh -o BatchMode=yes -o ClearAllForwardings=yes "$termux_workbench_host" \
      'cat "${XDG_CACHE_HOME:-$HOME/.cache}/distributed-workbench-bootstrap/termux-current.tar.gz"' \
      >"$termux_workbench_archive" || {
        printf '%s\n' 'termux: peer bootstrap artifact is unavailable' >&2
        return 1
      }
    termux_workbench_unpack=$termux_workbench_cache/bootstrap
    mkdir -p "$termux_workbench_unpack"
    tar -C "$termux_workbench_unpack" -xzf "$termux_workbench_archive" || return 1
    termux_workbench_root=$termux_workbench_unpack/distributed-workbench-$termux_workbench_remote_version-aarch64-linux-android
    DISTRIBUTED_WORKBENCH_CONTROLLER_ID=$termux_workbench_node_id \
      "$termux_workbench_root/scripts/install-termux-user.sh" \
      "$termux_workbench_root/bin/workbench" "$termux_workbench_node_id-rust" "$HOME" || return 1
  fi
  "$HOME/.local/bin/connect-termux-peer" "$termux_workbench_host" "$termux_workbench_node_id" || return 1
  printf 'termux: distributed-workbench node %s is connected through %s\n' \
    "$termux_workbench_node_id" "$termux_workbench_host"
}

termux_default_shell_setup()
{
  termux_zsh=$(command -v zsh 2>/dev/null || true)
  [ -n "$termux_zsh" ] || {
    printf '%s\n' 'termux: zsh is unavailable; cannot change the default shell' >&2
    return 1
  }

  if [ "$(readlink "$HOME/.termux/shell" 2>/dev/null || true)" = "$termux_zsh" ]; then
    printf 'Default shell is already %s\n' "$termux_zsh"
    return 0
  fi

  printf 'Changing default shell to %s...\n' "$termux_zsh"
  # Termux's chsh is a wrapper that expects a basename and prepends $PREFIX/bin.
  chsh -s zsh
}

termux_basic_setup()
{
  basic_env_setup
  termux_shell_setup
}

prepare_termux_env()
{
  termux_mode=$1
  if [ "$termux_mode" = all ]; then
    printf '%s\n' 'Warning: Termux has no additional all package set; using core.' >&2
    termux_mode=core
  fi

  [ "$termux_mode" = core ] || {
    printf 'termux: unsupported provisioning mode: %s\n' "$termux_mode" >&2
    return 2
  }

  install_termux_core_packages
  termux_default_shell_setup
  zinit_install
  termux_basic_setup
  tmux_plugins_setup
  if command -v tmux-agent-workbench >/dev/null 2>&1; then
    tmux-agent-workbench client setup termux
  else
    printf '%s\n' 'termux: tmux-agent-workbench unavailable; mobile notifications are not configured' >&2
  fi
  vim_plugins_setup
  termux_ssh_setup
  termux_distributed_workbench_setup

  printf '\n%s\n' 'Termux core setup complete. Public SSH key:'
  cat "$HOME/.ssh/id_ed25519.pub"
}
