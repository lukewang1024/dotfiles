# Util join function
function join { local IFS="$1"; shift; echo "$*"; }
function join_by_multi { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }

exists()
{
  command -v "$1" >/dev/null 2>&1
}

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

  if [[ -d $1 || "$OSTYPE" == 'darwin'* ]]; then
    args="-s"
  elif [[ "$OSTYPE" == 'linux-gnu' || "$OSTYPE" == 'cygwin' ]]; then
    args="-sb"
  fi
  eval "ln -v $args $1 ${2:-.}"
}

backup_then_symlink()
{
  if [[ -z "$1" ]]; then
    echo '[util.backupAndSymlink] No target file provided, return...'
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

blank_lines()
{
  echo
  echo
}

# Print the usage of the script and exit
print_usage()
{
  echo './init [platform] [option]'
  echo
  echo 'List of platforms:'
  echo
  echo '  macos | osx - macOS'
  echo '  debian      - Debian'
  echo '  arch        - Arch Linux'
  echo '  chromeos    - ChromeOS (requires developer mode)'
  echo '  cygwin      - Cygwin'
  echo
  echo 'List of options:'
  echo
  echo '  core - Prepare core environment only (default)'
  echo '  cli  - Prepare CLI environment only'
  echo '  gui  - Prepare GUI environment only'
  echo '  all  - Prepare both environments'
  echo '  game - Setup some games'
  echo
  echo 'Other tasks:'
  echo
  echo '  basic - Only link rc files to $HOME'
  echo '  npmg  - Install global npm packages (in case of version switch in nvm)'
  echo '  zgen  - Use zgen as preferred zsh plugin manager'
  echo '  zplug - Use zplug as preferred zsh plugin manager'
  echo '  run   - Run arbitrary function in any bootstrap scripts'
  echo '    `./init run [module] [task]`, below are tasks available:'
  echo '    `macos backup_automator_stuff`: Backup Automator stuff to Dropbox'
  echo '    `macos install_mac_wechat_plugin`: Tweak WeChat to save login session'
  echo
  exit 1
}
