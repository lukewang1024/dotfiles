source "$partial_dir/nix.sh"

# Use LinuxBrew for latest version of tools
install_linuxbrew()
{
  if ! exists brew; then
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Make sure brew can be found right after installation
    [ -d ~/.linuxbrew ] && eval "$(~/.linuxbrew/bin/brew shellenv)"
    [ -d /home/linuxbrew/.linuxbrew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}

install_linux_brew_core_packages()
{
  install_nix_brew_runtimes
  install_nix_brew_core_packages
}

install_linux_brew_extra_packages()
{
  install_nix_brew_extra_packages
}

install_i3ass()
{
  echo 'Installing i3ass...'
  sync_config_repo ~/.config/i3ass https://github.com/budRich/i3ass
  (cd ~/.config/i3ass && ./install.sh -q ~/bin)
  echo 'Done.'
}

install_st()
{
  sync_config_repo /tmp/st https://github.com/lukewang1024/st
  (cd /tmp/st && sudo make install)
}

apply_linux_app_configs()
{
  apply_nix_app_configs

  backup_then_symlink "$config_dir/aria2" ~/.aria2
  backup_then_symlink "$config_dir/compton/compton.conf" ~/.config/compton.conf
  backup_then_symlink "$config_dir/dunst" ~/.config/dunst
  backup_then_symlink "$config_dir/flameshot" ~/.config/Dharkael
  backup_then_symlink "$config_dir/fontconfig" ~/.config/fontconfig
  backup_then_symlink "$config_dir/gsimplecal" ~/.config/gsimplecal
  backup_then_symlink "$config_dir/gtk-2.0" ~/.config/gtk-2.0
  backup_then_symlink "$config_dir/gtk-2.0/.gtkrc-2.0" ~/.gtkrc-2.0
  backup_then_symlink "$config_dir/gtk-3.0" ~/.config/gtk-3.0
  backup_then_symlink "$config_dir/i3" ~/.config/i3
  backup_then_symlink "$config_dir/mpv" ~/.config/mpv
  backup_then_symlink "$config_dir/polipo" ~/.config/polipo
  backup_then_symlink "$config_dir/polybar" ~/.config/polybar
  backup_then_symlink "$config_dir/ranger/linux" ~/.config/ranger
  backup_then_symlink "$config_dir/redshift/redshift.conf" ~/.config/redshift.conf
  backup_then_symlink "$config_dir/rofi" ~/.config/rofi
  backup_then_symlink "$config_dir/thunar" ~/.config/Thunar
  backup_then_symlink "$config_dir/tilda" ~/.config/tilda
  backup_then_symlink "$config_dir/vnc/.vncrc" ~/.vncrc
  backup_then_symlink "$config_dir/x/.xbindkeysrc" ~/.xbindkeysrc
  backup_then_symlink "$config_dir/x/.xinitrc" ~/.xinitrc
  backup_then_symlink "$config_dir/x/.Xmodmap" ~/.Xmodmap
  backup_then_symlink "$config_dir/x/.Xresources" ~/.Xresources
  backup_then_symlink "$config_dir/x/.Xresources.d" ~/.Xresources.d
  backup_then_symlink "$config_dir/x/.xscreensaver" ~/.xscreensaver
  backup_then_symlink "$config_dir/zathura" ~/.config/zathura
  backup_then_symlink ~/Dropbox/Sync/Rime ~/.config/fcitx/rime/sync

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
  backup_then_symlink "$util_dir/linux/lock" ~/bin/lock
  backup_then_symlink "$util_dir/linux/record-audio" ~/bin/record-audio
  backup_then_symlink "$util_dir/linux/record-screencast" ~/bin/record-screencast
  backup_then_symlink "$util_dir/linux/record-video" ~/bin/record-video
  backup_then_symlink "$util_dir/linux/touchpad-toggle" ~/bin/touchpad-toggle
  backup_then_symlink "$util_dir/linux/wallpaper" ~/bin/wallpaper
  backup_then_symlink "$util_dir/linux/window-move" ~/bin/window-move
  backup_then_symlink "$util_dir/linux/window-resize" ~/bin/window-resize
  backup_then_symlink "$util_dir/linux/xrun" ~/bin/xrun

  # Misc settings
  mkdir -p ~/.polipo-cache
  mkdir -p ~/Recordings
  touch "$config_dir/x/.Xresources.d/custom"

  # Refresh font cache
  fc-cache -f -v
}

install_flatpak_packages()
{
  local pkgs=()
  flatpak install -y flathub `join ' ' "${pkgs[@]}"`
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
