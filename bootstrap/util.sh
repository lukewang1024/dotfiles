# Util join function
function join { local IFS="$1"; shift; echo "$*"; }

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

  if [[ -d $1 || "$OSTYPE" == 'darwin'* ]]; then
    args="-s"
  elif [[ "$OSTYPE" == 'linux-gnu' || "$OSTYPE" == 'cygwin' ]]; then
    args="-sb"
  fi
  eval "ln $args $1 ${2:-.}"
}

backupThenSymlink()
{
  if [[ -z "$1" ]]; then
    echo '[util.backupAndSymlink] No target file provided, return...'
    return
  fi

  backup $2
  symlink $1 $2
}

# Print the usage of the script and exit
printUsage()
{
  echo './init [platform] [option]'
  echo
  echo 'List of platforms:'
  echo '  wsl    - Default WSL with Ubuntu (CLI only)'
  echo '  alwsl  - Custom WSL with Arch Linux (CLI only)'
  echo '  ubuntu - Ubuntu'
  echo '  arch   - Arch Linux'
  echo
  echo 'List of options:'
  echo
  echo '  cli - Prepare CLI environment only (default)'
  echo '  gui - Prepare GUI environment only'
  echo '  all - Prepare both environments'
  exit 1
}
