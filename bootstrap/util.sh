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
  usage_status=${1:-0}
  cat << 'EOB' >&2
Luke's config bootstrap script

[Synopsis]

./init basic | core | all
./init [task]

The platform is always detected; platform arguments are not accepted.

[Options]

  basic - Configure already-installed tools; install no platform packages
  core  - Install this platform's daily environment, then run basic
  all   - Install core plus platform extras, then run basic. On platforms with
          no extra set (including Termux), warn and use core.

[Tasks]

  npmg  - Install global npm packages (in case of version switch in nvm)
  zinit - Set zinit as the zsh plugin manager (symlinks .zshrc, etc.)
  kerberos - Interactively configure krb5.conf for an internal realm
  sync  - Reconcile an already-provisioned machine after `git pull`: re-run only
          the fast, idempotent link/plugin steps (no prompts/sudo/heavy installs).
          Auto-invoked by the repo's post-merge hook when provisioning files change.
  migrate-xdg - Move ~/.dotfiles to $XDG_CONFIG_HOME/dotfiles, retarget managed
          symlinks, and remove the temporary compatibility path. Supports
          --dry-run and is safe to repeat after an interrupted migration.
  workbench - Install or reconcile this machine as a Distributed Workbench node.
          Platform details and peer direction are selected automatically.
  run   - Run arbitrary function in any bootstrap scripts
    `./init run [module] [task]`, below are tasks available:
    `macos backup_automator_stuff`: Backup Automator stuff to Dropbox
    `macos install_mac_wechat_plugin`: Tweak WeChat to save login session
EOB
  exit "$usage_status"
}
