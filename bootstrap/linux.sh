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

install_st()
{
  sync_config_repo /tmp/st https://github.com/lukewang1024/st
  (cd /tmp/st && sudo make install)
}

apply_linux_app_configs()
{
  apply_nix_app_configs

  backup_then_symlink "$config_dir/aria2" ~/.aria2
  backup_then_symlink "$config_dir/dunst" ~/.config/dunst
  backup_then_symlink "$config_dir/flameshot" ~/.config/Dharkael
  backup_then_symlink "$config_dir/fontconfig" ~/.config/fontconfig
  backup_then_symlink "$config_dir/gsimplecal" ~/.config/gsimplecal
  backup_then_symlink "$config_dir/gtk-2.0" ~/.config/gtk-2.0
  backup_then_symlink "$config_dir/gtk-2.0/.gtkrc-2.0" ~/.gtkrc-2.0
  backup_then_symlink "$config_dir/gtk-3.0" ~/.config/gtk-3.0
  backup_then_symlink "$config_dir/i3" ~/.config/i3
  backup_then_symlink "$config_dir/mpv" ~/.config/mpv
  backup_then_symlink "$config_dir/picom" ~/.config/picom
  backup_then_symlink "$config_dir/polipo" ~/.config/polipo
  backup_then_symlink "$config_dir/polybar" ~/.config/polybar
  backup_then_symlink "$config_dir/privoxy" ~/.config/privoxy
  backup_then_symlink "$config_dir/ranger/linux" ~/.config/ranger
  backup_then_symlink "$config_dir/redshift/redshift.conf" ~/.config/redshift.conf
  backup_then_symlink "$config_dir/rofi" ~/.config/rofi
  backup_then_symlink "$config_dir/systemd" ~/.config/systemd
  backup_then_symlink "$config_dir/thunar" ~/.config/Thunar
  backup_then_symlink "$config_dir/tilda" ~/.config/tilda
  backup_then_symlink "$config_dir/v2ray" ~/.config/v2ray
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
  backup_then_symlink "$config_dir/polybar/launch-bars" "$bin_dir/polybar-launch"
  backup_then_symlink "$util_dir/linux/chrome-launcher" "$bin_dir/chrome-launcher"
  backup_then_symlink "$util_dir/linux/dmenu-display" "$bin_dir/dmenu-display"
  backup_then_symlink "$util_dir/linux/dmenu-handler" "$bin_dir/dmenu-handler"
  backup_then_symlink "$util_dir/linux/dmenu-i3" "$bin_dir/dmenu-i3"
  backup_then_symlink "$util_dir/linux/dmenu-mount" "$bin_dir/dmenu-mount"
  backup_then_symlink "$util_dir/linux/dmenu-power" "$bin_dir/dmenu-power"
  backup_then_symlink "$util_dir/linux/dmenu-prompt" "$bin_dir/dmenu-prompt"
  backup_then_symlink "$util_dir/linux/dmenu-record" "$bin_dir/dmenu-record"
  backup_then_symlink "$util_dir/linux/dmenu-umount" "$bin_dir/dmenu-umount"
  backup_then_symlink "$util_dir/linux/enable-exec" "$bin_dir/enable-exec"
  backup_then_symlink "$util_dir/linux/kbmod" "$bin_dir/kbmod"
  backup_then_symlink "$util_dir/linux/local-http-proxy" "$bin_dir/local-http-proxy"
  backup_then_symlink "$util_dir/linux/lock" "$bin_dir/lock"
  backup_then_symlink "$util_dir/linux/record-audio" "$bin_dir/record-audio"
  backup_then_symlink "$util_dir/linux/record-screencast" "$bin_dir/record-screencast"
  backup_then_symlink "$util_dir/linux/record-video" "$bin_dir/record-video"
  backup_then_symlink "$util_dir/linux/ssh-agent-per-user" "$bin_dir/ssh-agent-per-user"
  backup_then_symlink "$util_dir/linux/thunar-launcher" "$bin_dir/thunar-launcher"
  backup_then_symlink "$util_dir/linux/touchpad-toggle" "$bin_dir/touchpad-toggle"
  backup_then_symlink "$util_dir/linux/wallpaper" "$bin_dir/wallpaper"
  backup_then_symlink "$util_dir/linux/window-move" "$bin_dir/window-move"
  backup_then_symlink "$util_dir/linux/window-resize" "$bin_dir/window-resize"
  backup_then_symlink "$util_dir/linux/xrun" "$bin_dir/xrun"

  # Misc settings
  mkdir -p ~/.cache/polipo
  mkdir -p ~/Recordings
  touch "$config_dir/x/.Xresources.d/custom"

  # Desktop entries
  sudo cp -f "$config_dir/xsessions/i3-systemd.desktop" /usr/share/xsessions/i3-systemd.desktop
  backup_then_symlink "$config_dir/xsessions/i3-systemd-init" "$bin_dir/i3-systemd-init"
  sudo cp -f "$config_dir/xsessions/xfce-systemd.desktop" /usr/share/xsessions/xfce-systemd.desktop
  backup_then_symlink "$config_dir/xsessions/xfce-systemd-init" "$bin_dir/xfce-systemd-init"

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
