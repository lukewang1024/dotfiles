source "$partial_dir/nix.sh"

# Use LinuxBrew for latest version of tools
installLinuxBrew()
{
  exists brew || \
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install)" && \
    # Make sure brew can be found right after installation
    PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

  brew update; brew upgrade
}

applyAppConfigs()
{
  backupThenSymlink "$config_dir/i3" ~/.config/i3
  backupThenSymlink "$config_dir/polybar" ~/.config/polybar
  backupThenSymlink "$config_dir/gsimplecal" ~/.config/gsimplecal
  backupThenSymlink "$config_dir/x/.xinitrc" ~/.xinitrc
  backupThenSymlink "$config_dir/x/.Xresources" ~/.Xresources
  backupThenSymlink "$config_dir/x/.Xmodmap" ~/.Xmodmap
  backupThenSymlink "$config_dir/redshift/redshift.conf" ~/.config/redshift.conf
  backupThenSymlink "$config_dir/aria2" ~/.aria2

  # Handy scripts
  backupThenSymlink "$util_dir/linux/enable-exec" ~/bin/enable-exec
  backupThenSymlink "$util_dir/linux/wallpaper" ~/bin/wallpaper
  backupThenSymlink "$util_dir/linux/zzz" ~/bin/zzz
  backupThenSymlink "$util_dir/xrandr/xrandr-both" ~/bin/xrandr-both
  backupThenSymlink "$util_dir/xrandr/xrandr-hdmi" ~/bin/xrandr-hdmi
  backupThenSymlink "$util_dir/xrandr/xrandr-int" ~/bin/xrandr-int
}

fixENOSPC()
{
  echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
}

# Make sure default locale is available
fixLocale()
{
  sudo localedef -i en_US -f UTF-8 en_US.UTF-8
}
