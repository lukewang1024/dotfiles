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
  backupThenSymlink "$config_dir/compton/compton.conf" ~/.config/compton.conf
  backupThenSymlink "$config_dir/aria2" ~/.aria2
  backupThenSymlink ~/Dropbox/Sync/Rime ~/.config/fcitx/rime/sync

  # Handy scripts
  backupThenSymlink "$util_dir/linux/dmenu-display" ~/bin/dmenu-display
  backupThenSymlink "$util_dir/linux/dmenu-handler" ~/bin/dmenu-handler
  backupThenSymlink "$util_dir/linux/dmenu-mount" ~/bin/dmenu-mount
  backupThenSymlink "$util_dir/linux/dmenu-prompt" ~/bin/dmenu-prompt
  backupThenSymlink "$util_dir/linux/dmenu-record" ~/bin/dmenu-record
  backupThenSymlink "$util_dir/linux/dmenu-umount" ~/bin/dmenu-umount
  backupThenSymlink "$util_dir/linux/enable-exec" ~/bin/enable-exec
  backupThenSymlink "$util_dir/linux/record-audio" ~/bin/record-audio
  backupThenSymlink "$util_dir/linux/record-screencast" ~/bin/record-screencast
  backupThenSymlink "$util_dir/linux/record-video" ~/bin/record-video
  backupThenSymlink "$util_dir/linux/wallpaper" ~/bin/wallpaper
  backupThenSymlink "$util_dir/linux/zzz" ~/bin/zzz

  # Misc settings
  mkdir -p "$HOME/Recordings"
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
