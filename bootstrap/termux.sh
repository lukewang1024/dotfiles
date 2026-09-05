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
  setup_distributed_workbench

  printf '\n%s\n' 'Termux core setup complete. Public SSH key:'
  cat "$HOME/.ssh/id_ed25519.pub"
}
