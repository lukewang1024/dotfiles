dotfiles_dir="${DOTFILES_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}"
[ -d "$dotfiles_dir" ] || dotfiles_dir="$HOME/.dotfiles"
config_dir="$dotfiles_dir/config"
source "$config_dir/utils.sh";

# Start graphical server if i3 not already running.
if is_linux && [ "$(tty)" = '/dev/tty1' ]; then
  pgrep -x i3 || exec startx
fi
