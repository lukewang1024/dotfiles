# shellcheck shell=sh
# Bootstrap ZDOTDIR before zsh looks for the shared XDG-managed startup files.
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# termux-services provides the ssh-agent service and its stable socket.
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-$PREFIX/var/run}/ssh-agent.socket"
