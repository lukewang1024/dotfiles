addKeys()
{
  # Add all private keys start with 'id_'
  ssh-add $(find ~/.ssh -name 'id_*' ! -name '*.*' | tr '\n' ' ')
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
    return
  fi

  if sshAgentSocketAvailable "$stable_agent_socket"; then
    export SSH_AUTH_SOCK="$stable_agent_socket"
    return
  fi

  # No reachable forwarded or local agent exists. A process-name check is not
  # sufficient here: an orphaned agent can still be running after its socket is
  # gone. Start a reachable one and refresh the stable symlink.
  spawnPerUserSSHAgent
  addKeys
}
