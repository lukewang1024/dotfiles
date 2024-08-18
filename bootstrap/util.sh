source "$config_dir/utils.sh"
source "$config_dir/sh/xdg-paths.sh"

# Back up target file with appending ~
backup()
{
  if [[ -z "$1" ]]; then
    echo '[util.backup] No target file provided, return...'
    return
  fi

  if [[ -h $1~ ]]; then
    eval "rm $1~"
  fi

  if [[ -f $1 || -d $1 || -h $1 ]]; then
    eval "mv $1 $1~"
  fi
}

symlink()
{
  if [[ -z "$1" ]]; then
    echo '[util.symlink] No target file provided, return...'
    return
  fi

  dir=$(dirname ${2:-.})
  mkdir -p "$dir"

  if [ -h $2 ]; then
    eval "rm $2"
  fi

  if [ -d $1 ] || is_macos; then
    args="-s"
  elif is_linux || is_cygwin; then
    args="-sb"
  fi
  eval "ln -v $args $1 ${2:-.}"
}

backup_then_symlink()
{
  if [[ -z "$1" ]]; then
    echo '[util.backup_then_symlink] No target file provided, return...'
    return
  fi

  backup $2
  symlink $1 $2
}

sync_config_repo()
{
  local configPath=$1
  local repoUrl=$2

  if [[ -d $configPath ]]; then
    if [[ -d $configPath/.git ]]; then
      ( cd $configPath && git pull )
      return
    fi

    backup $configPath
  fi

  git clone --depth 1 $repoUrl $configPath
}

blank_lines() { echo; echo; }

# Print the usage of the script and exit
print_usage()
{
  cat << 'EOB' >&2
Luke's config bootstrap script

[Synopsis]

./init [platform] [option]
./init [task]

[Platforms]

  macos | osx - macOS
  debian      - Debian
  arch        - Arch Linux
  chromeos    - ChromeOS (requires developer mode)
  cygwin      - Cygwin

[Options]

  core - Prepare core environment only (default)
  cli  - Prepare CLI environment only
  gui  - Prepare GUI environment only
  all  - Prepare both environments
  game - Setup some games

[Tasks]

  basic - Only link rc files to $HOME
  npmg  - Install global npm packages (in case of version switch in nvm)
  zgen  - Use zgen as preferred zsh plugin manager
  zinit - Use zinit as preferred zsh plugin manager
  run   - Run arbitrary function in any bootstrap scripts
    `./init run [module] [task]`, below are tasks available:
    `macos backup_automator_stuff`: Backup Automator stuff to Dropbox
    `macos install_mac_wechat_plugin`: Tweak WeChat to save login session
EOB
  exit 0
}
