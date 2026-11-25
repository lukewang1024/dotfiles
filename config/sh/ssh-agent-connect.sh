addKeys()
{
  # Add every recognized private key in ~/.ssh that is not already loaded.
  # Collect them first and invoke ssh-add once: OpenSSH retries the last
  # passphrase for subsequent identity files in the same invocation.
  loaded_keys=$(ssh-add -l 2>/dev/null | awk '{ print $2 }')
  add_keys_status=0
  set --
  key=

  for key in "$HOME"/.ssh/*; do
    [ -f "$key" ] && [ -r "$key" ] || continue
    key_header=
    IFS= read -r key_header < "$key" || continue
    case "$key_header" in
      '-----BEGIN OPENSSH PRIVATE KEY-----'|\
      '-----BEGIN RSA PRIVATE KEY-----'|\
      '-----BEGIN EC PRIVATE KEY-----'|\
      '-----BEGIN DSA PRIVATE KEY-----'|\
      '-----BEGIN PRIVATE KEY-----'|\
      '-----BEGIN ENCRYPTED PRIVATE KEY-----') ;;
      *) continue ;;
    esac

    fingerprint=$(ssh-keygen -lf "$key" 2>/dev/null | awk 'NR == 1 { print $2; exit }')
    [ -n "$fingerprint" ] || continue

    case "$loaded_keys" in
      *"$fingerprint"*)
        continue
        ;;
    esac

    set -- "$@" "$key"
  done

  if [ "$#" -gt 0 ]; then
    biometric_ssh_add="$HOME/.local/bin/ssh-add-biometric"
    if [ -n "${TERMUX_VERSION:-}" ] && [ -x "$biometric_ssh_add" ]; then
      # Shell startup must explain the Android prompt and wait for the user.
      # Never read from redirected input or launch biometrics in a background job.
      if [ -t 0 ] && [ -t 1 ]; then
        printf '%s\n' '检测到 SSH 指纹工具，部分密钥尚未加入 ssh-agent。' >&2
        printf '%s' '按回车打开指纹认证并加载密钥；输入其他内容后回车跳过：' >&2
        if IFS= read -r biometric_reply && [ -z "$biometric_reply" ]; then
          "$biometric_ssh_add" "$@" || add_keys_status=1
        fi
      fi
    else
      ssh-add "$@" || add_keys_status=1
    fi
  fi
  return "$add_keys_status"
}

sshAgentSocketAvailable()
{
  [ -n "${1:-}" ] && [ -S "$1" ] || return 1

  SSH_AUTH_SOCK=$1 ssh-add -l >/dev/null 2>&1
  ssh_add_status=$?
  # ssh-add returns 1 for a reachable agent with no identities and 2 when it
  # cannot contact an agent. Both a loaded and an empty agent are usable.
  [ "$ssh_add_status" -ne 2 ]
}

stableSSHAgentSocket()
{
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/ssh-agent/socket"
}

publishSSHAgentSocket()
{
  real_agent_socket=$SSH_AUTH_SOCK
  stable_agent_socket=$(stableSSHAgentSocket)

  [ "$real_agent_socket" = "$stable_agent_socket" ] || {
    mkdir -p "$(dirname "$stable_agent_socket")"
    ln -sfn "$real_agent_socket" "$stable_agent_socket"
  }
  export SSH_AUTH_SOCK="$stable_agent_socket"
}

spawnPerUserSSHAgent()
{
  eval $(ssh-agent)
  publishSSHAgentSocket
  printf 'export SSH_AGENT_PID=%s\n' "$SSH_AGENT_PID" > ~/.agent-profile
  printf 'export SSH_AUTH_SOCK=%s\n' "$SSH_AUTH_SOCK" >> ~/.agent-profile
}

connectSSHAgent()
{
  stable_agent_socket=$(stableSSHAgentSocket)

  if sshAgentSocketAvailable "${SSH_AUTH_SOCK:-}"; then
    if [ -n "${SSH_CONNECTION:-}" ]; then
      # sshd supplies a connection-scoped socket for agent forwarding. Keep it:
      # publishing it would make a short-lived remote login the machine-wide
      # stable agent, and replacing it would disable forwarding for this shell.
      return
    fi

    # Local shells all use one stable pathname. If the underlying agent is
    # replaced, repointing this symlink repairs existing shells and tmux panes.
    publishSSHAgentSocket
    addKeys
    return
  fi

  if sshAgentSocketAvailable "$stable_agent_socket"; then
    export SSH_AUTH_SOCK="$stable_agent_socket"
    addKeys
    return
  fi

  # No reachable forwarded or local agent exists. A process-name check is not
  # sufficient here: an orphaned agent can still be running after its socket is
  # gone. Start a reachable one and refresh the stable symlink.
  spawnPerUserSSHAgent
  addKeys
}
