source "$partial_dir/nix.sh"

# Use LinuxBrew for latest version of tools
install_linuxbrew()
{
  exists brew || \
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install)" && \
    # Make sure brew can be found right after installation
    PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

  brew update; brew upgrade
}

install_i3ass()
{
  echo 'Installing i3ass...'
  sync_config_repo ~/.config/i3ass https://github.com/budRich/i3ass
  (cd ~/.config/i3ass && ./install.sh -q ~/bin)
  echo 'Done.'
}

apply_app_configs()
{
  backup_then_symlink "$config_dir/aria2" ~/.aria2
  backup_then_symlink "$config_dir/compton/compton.conf" ~/.config/compton.conf
  backup_then_symlink "$config_dir/dunst" ~/.config/dunst
  backup_then_symlink "$config_dir/gsimplecal" ~/.config/gsimplecal
  backup_then_symlink "$config_dir/i3" ~/.config/i3
  backup_then_symlink "$config_dir/mpv" ~/.config/mpv
  backup_then_symlink "$config_dir/polybar" ~/.config/polybar
  backup_then_symlink "$config_dir/polipo" ~/.config/polipo
  backup_then_symlink "$config_dir/redshift/redshift.conf" ~/.config/redshift.conf
  backup_then_symlink "$config_dir/rofi" ~/.config/rofi
  backup_then_symlink "$config_dir/x/.xbindkeysrc" ~/.xbindkeysrc
  backup_then_symlink "$config_dir/x/.xinitrc" ~/.xinitrc
  backup_then_symlink "$config_dir/x/.Xmodmap" ~/.Xmodmap
  backup_then_symlink "$config_dir/x/.Xresources" ~/.Xresources
  backup_then_symlink "$config_dir/x/.xscreensaver" ~/.xscreensaver
  backup_then_symlink ~/Dropbox/Sync/Rime ~/.config/fcitx/rime/sync

  mkdir -p ~/.polipo-cache

  # Handy scripts
  backup_then_symlink "$config_dir/polybar/launch-bars" ~/bin/polybar-launch
  backup_then_symlink "$util_dir/linux/chrome-launcher" ~/bin/chrome-launcher
  backup_then_symlink "$util_dir/linux/dmenu-display" ~/bin/dmenu-display
  backup_then_symlink "$util_dir/linux/dmenu-handler" ~/bin/dmenu-handler
  backup_then_symlink "$util_dir/linux/dmenu-mount" ~/bin/dmenu-mount
  backup_then_symlink "$util_dir/linux/dmenu-power" ~/bin/dmenu-power
  backup_then_symlink "$util_dir/linux/dmenu-prompt" ~/bin/dmenu-prompt
  backup_then_symlink "$util_dir/linux/dmenu-record" ~/bin/dmenu-record
  backup_then_symlink "$util_dir/linux/dmenu-umount" ~/bin/dmenu-umount
  backup_then_symlink "$util_dir/linux/enable-exec" ~/bin/enable-exec
  backup_then_symlink "$util_dir/linux/kbmod" ~/bin/kbmod
  backup_then_symlink "$util_dir/linux/record-audio" ~/bin/record-audio
  backup_then_symlink "$util_dir/linux/record-screencast" ~/bin/record-screencast
  backup_then_symlink "$util_dir/linux/record-video" ~/bin/record-video
  backup_then_symlink "$util_dir/linux/touchpad-toggle" ~/bin/touchpad-toggle
  backup_then_symlink "$util_dir/linux/wallpaper" ~/bin/wallpaper

  # Misc settings
  mkdir -p "$HOME/Recordings"
}

fix_ENOSPC()
{
  local tweak='fs.inotify.max_user_watches=524288'
  if [ -f /etc/arch-release ]; then
    echo "$tweak" | sudo tee /etc/sysctl.d/40-max-user-watches.conf && sudo sysctl --system
  else
    echo "$tweak" | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
  fi
}

# Make sure default locale is available
fix_locale()
{
  sudo localedef -i en_US -f UTF-8 en_US.UTF-8
}
