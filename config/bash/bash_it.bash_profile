config_dir="$HOME/.dotfiles/config"

if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi

source "$config_dir/sh/profile.sh"
