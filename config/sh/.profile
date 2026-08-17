dotfiles_dir="${DOTFILES_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}"
[ -d "$dotfiles_dir" ] || dotfiles_dir="$HOME/.dotfiles"
config_dir="$dotfiles_dir/config"

source "$config_dir/utils.sh";
source "$config_dir/sh/rc.sh"
