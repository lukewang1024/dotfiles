# Non-interactive zsh commands (including commands invoked through ssh) do not
# source .zshrc, but user-installed commands still need to be discoverable.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
