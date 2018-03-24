source "$partial_dir/nix.sh"

# Use LinuxBrew for latest version of tools
installLinuxBrew()
{
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install)"
  # Make sure brew can be found right after installation
  PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
}

installLinuxBrewBuildTools()
{
  # Build tools
  pkgs=(
    bzip2
    gcc
    openssl
    readline
    sqlite
    xz
  )
  brewInstallPkgs
}

applyAppConfigs()
{
  backupThenSymlink "$config_dir/i3" ~/.config/i3
  backupThenSymlink "$config_dir/polybar" ~/.config/polybar
  backupThenSymlink "$config_dir/x/.Xmodmap" ~/.Xmodmap
  backupThenSymlink "$config_dir/redshift/redshift.conf" ~/.config/redshift.conf

  # Handy scripts
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
