# Alpine's /etc/zprofile resets PATH after .zshenv. Restore the iSH environment
# for login commands too: ssh and tmux workers do not read interactive .zshrc.
if [ "${DOTFILES_PLATFORM:-}" = ish ]; then
  # shellcheck source=config/ish/env.sh
  . "${DOTFILES_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}/config/ish/env.sh"
fi
