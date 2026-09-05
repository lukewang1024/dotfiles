#!/bin/sh
# shellcheck disable=SC2154 # sourced by init, which defines shared paths

# Platform-neutral entrypoint for installing this node into Distributed
# Workbench. Platform details stay behind setup_distributed_workbench.

workbench_release_installer()
{
  workbench_cache=${XDG_CACHE_HOME:-"$HOME/.cache"}/distributed-workbench
  workbench_installer=$workbench_cache/install-from-release.sh
  mkdir -p "$workbench_cache"
  curl -fsSL \
    https://raw.githubusercontent.com/lukewang1024/distributed-workbench/main/scripts/install-from-release.sh \
    -o "$workbench_installer" || return 1
  chmod 755 "$workbench_installer"
}

workbench_default_node_id()
{
  if [ "${DOTFILES_PLATFORM:-}" = termux ]; then
    workbench_model=$(getprop ro.product.model 2>/dev/null || printf '%s' termux)
    workbench_model=$(printf '%s' "$workbench_model" |
      tr '[:upper:]' '[:lower:]' |
      sed 's/[^a-z0-9._-][^a-z0-9._-]*/-/g; s/^-//; s/-$//')
    [ -n "$workbench_model" ] || workbench_model=termux
    printf '%s-termux\n' "$workbench_model"
    return
  fi
  hostname -s
}

workbench_peer_local_config()
{
  workbench_config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}/distributed-workbench
  workbench_config=$workbench_config_home/peer.conf
  workbench_legacy_config=$workbench_config_home/termux-peer.conf
  if [ ! -f "$workbench_config" ] && [ -f "$workbench_legacy_config" ]; then
    mv "$workbench_legacy_config" "$workbench_config"
  fi
  if [ -f "$workbench_config" ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    printf '%s\n' \
      "workbench: peer setup needs $workbench_config or an interactive run" >&2
    return 1
  fi

  printf '%s' 'SSH alias for an existing workbench node (empty to skip): '
  IFS= read -r workbench_peer_host
  [ -n "$workbench_peer_host" ] || return 1
  case $workbench_peer_host in
    *[!0-9A-Za-z._-]*)
      printf 'workbench: invalid SSH alias: %s\n' "$workbench_peer_host" >&2
      return 1
      ;;
  esac
  workbench_node_id=$(workbench_default_node_id)
  mkdir -p "$workbench_config_home"
  umask 077
  {
    printf 'DISTRIBUTED_WORKBENCH_PEER_HOST=%s\n' "$workbench_peer_host"
    printf 'DISTRIBUTED_WORKBENCH_NODE_ID=%s\n' "$workbench_node_id"
    printf '%s\n' 'DISTRIBUTED_WORKBENCH_VERSION=latest'
  } >"$workbench_config"
  chmod 600 "$workbench_config"
}

setup_termux_workbench_peer()
{
  workbench_peer_local_config || return 0
  workbench_peer_host=$(sed -n 's/^DISTRIBUTED_WORKBENCH_PEER_HOST=//p' "$workbench_config" | tail -1)
  workbench_node_id=$(sed -n -e 's/^DISTRIBUTED_WORKBENCH_NODE_ID=//p' \
    -e 's/^DISTRIBUTED_WORKBENCH_TERMUX_NODE_ID=//p' "$workbench_config" | tail -1)
  workbench_version=$(sed -n 's/^DISTRIBUTED_WORKBENCH_VERSION=//p' "$workbench_config" | tail -1)
  workbench_version=${workbench_version:-latest}
  for workbench_value in "$workbench_peer_host" "$workbench_node_id" "$workbench_version"; do
    case $workbench_value in
      ''|*[!0-9A-Za-z._-]*)
        printf 'workbench: invalid value in %s\n' "$workbench_config" >&2
        return 2
        ;;
    esac
  done

  if ! ssh -o BatchMode=yes -o ClearAllForwardings=yes "$workbench_peer_host" true; then
    printf 'workbench: SSH alias %s is not ready; peer setup deferred\n' "$workbench_peer_host" >&2
    return 1
  fi

  workbench_release_installer || return 1
  if ! DISTRIBUTED_WORKBENCH_CONTROLLER_ID=$workbench_node_id \
    DISTRIBUTED_WORKBENCH_EXECUTOR_ID=$workbench_node_id-rust \
    "$workbench_installer" "$workbench_version" "$HOME"; then
    printf '%s\n' 'workbench: published Android release unavailable; trying the authenticated peer bootstrap cache' >&2
    workbench_remote_version_output=$(ssh -o BatchMode=yes -o ClearAllForwardings=yes \
      "$workbench_peer_host" '"$HOME/.local/bin/workbench" --version') || return 1
    workbench_remote_version=$(printf '%s\n' "$workbench_remote_version_output" | awk 'NR == 1 {print $2}')
    case $workbench_remote_version in
      ''|*[!0-9A-Za-z._-]*)
        printf '%s\n' 'workbench: peer returned an invalid version' >&2
        return 1
        ;;
    esac
    workbench_archive=$workbench_cache/termux-current.tar.gz
    ssh -o BatchMode=yes -o ClearAllForwardings=yes "$workbench_peer_host" \
      'cat "${XDG_CACHE_HOME:-$HOME/.cache}/distributed-workbench-bootstrap/termux-current.tar.gz"' \
      >"$workbench_archive" || return 1
    workbench_unpack=$workbench_cache/bootstrap
    mkdir -p "$workbench_unpack"
    tar -C "$workbench_unpack" -xzf "$workbench_archive" || return 1
    workbench_root=$workbench_unpack/distributed-workbench-$workbench_remote_version-aarch64-linux-android
    DISTRIBUTED_WORKBENCH_CONTROLLER_ID=$workbench_node_id \
      "$workbench_root/scripts/install-termux-user.sh" \
      "$workbench_root/bin/workbench" "$workbench_node_id-rust" "$HOME" || return 1
  fi
  "$HOME/.local/bin/connect-termux-peer" "$workbench_peer_host" "$workbench_node_id" || return 1
  printf 'workbench: node %s is connected through %s\n' "$workbench_node_id" "$workbench_peer_host"
}

setup_distributed_workbench()
{
  case ${DOTFILES_PLATFORM:-} in
    termux)
      setup_termux_workbench_peer
      ;;
    macos|debian|arch|chromeos)
      workbench_release_installer || return 1
      "$workbench_installer" latest
      ;;
    *)
      printf 'workbench: unsupported platform: %s\n' "${DOTFILES_PLATFORM:-unknown}" >&2
      return 2
      ;;
  esac
}
