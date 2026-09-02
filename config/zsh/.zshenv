# Non-interactive zsh commands (including commands invoked through ssh) do not
# source .zshrc, but user-installed commands still need to be discoverable.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Non-interactive shells do not run the full agent reconciliation from .zshrc.
# Preserve a live forwarded agent when one is present; otherwise make the
# stable per-user agent socket available without spawning a process or running
# ssh-add on every shell startup.
ssh_agent_stable_socket=${XDG_STATE_HOME:-$HOME/.local/state}/ssh-agent/socket
if [ -z "${SSH_AUTH_SOCK:-}" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
  if [ -S "$ssh_agent_stable_socket" ]; then
    export SSH_AUTH_SOCK=$ssh_agent_stable_socket
  fi
fi
unset ssh_agent_stable_socket
