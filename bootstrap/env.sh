source "$partial_dir/shell.sh"
source "$partial_dir/pkg.sh"

git_setup()
{
  blank_lines
  echo 'Applying global git configs...'

  # Back up the current config file
  if [ -f ~/.gitconfig ]; then
    printf 'Backing up current .gitconfig... '
    local git_user_identities="$(git config --global --list | grep -E '^user\.\w+\.\w+=.+$')"
    mv ~/.gitconfig ~/.gitconfig~
    echo 'Done.'
  fi

  echo 'Applying new git configs...'
  cat "$config_dir/git/alias" > ~/.gitconfig
  cat "$config_dir/git/common" >> ~/.gitconfig
  [ -f "$config_dir/git/local" ] && cat "$config_dir/git/local" >> ~/.gitconfig

  backup_then_symlink "$util_dir/shell/git-set-identity" ~/bin/git-set-identity

  # MacOS
  if is_macos; then
    git config --global credential.helper osxkeychain
  fi

  # WSL & Cygwin
  uname -r | grep Microsoft &> /dev/null # returns 0 on WSL
  if [[ $? == 0 ]] || is_cygwin; then
    git config --global core.autocrlf input
    git config --global core.fileMode false
  fi

  # Git user identities
  if [ -n "$git_user_identities" ]; then
    echo 'Git user identities were configured as below previously.'
    echo "$git_user_identities"
    read -p 'Do you want to re-apply them? [Y/n]' -n 1 -r; echo
    if [ -z $REPLY ] || [ $REPLY = 'y' ] || [ $REPLY = 'Y' ]; then
      sedCmd=$(is_macos && echo gsed || echo sed)
      eval "$(echo "$git_user_identities" | $sedCmd -E 's/^(user\.\w+\.\w+)=(.+)$/git config --global \1 "\2"/g')"
      echo 'Previous identities re-applied.'
    fi
  fi

  while : ; do
    read -p 'Add a new identity (Leave blank to skip):' -r git_user_identity; echo
    if [ -z "$git_user_identity" ]; then echo 'Skipped.'; break; fi

    while : ; do
      read -p 'Name:' git_user_name
      [ -n "$git_user_name" ] && break
      echo 'Name cannot be empty!'
    done

    while : ; do
      read -p 'Email:' git_user_email
      [ -n "$git_user_email" ] && break
      echo 'Email cannot be empty!'
    done

    read -p 'SigningKey:' git_user_signingKey

    git config --global "user.$git_user_identity.name" "$git_user_name"
    git config --global "user.$git_user_identity.email" "$git_user_email"
    if [ -n "$git_user_signingKey" ]; then
      git config --global "user.$git_user_identity.signingKey" "$git_user_signingKey"
    fi
  done

  unset git_user_identity
  unset git_user_name
  unset git_user_email
  unset git_user_signingKey

  echo 'Done.'
}

rbenv_setup()
{
  blank_lines
  echo 'Installing rbenv...'
  local GH='https://github.com'
  local ROOT="$HOME/.rbenv"
  local PLUGINS="$ROOT/plugins"
  sync_config_repo "$ROOT"                        "$GH/rbenv/rbenv"
  sync_config_repo "$PLUGINS/ruby-build"          "$GH/rbenv/ruby-build"
  sync_config_repo "$PLUGINS/rbenv-vars"          "$GH/rbenv/rbenv-vars"
  sync_config_repo "$PLUGINS/rbenv-each"          "$GH/rbenv/rbenv-each"
  sync_config_repo "$PLUGINS/rbenv-default-gems"  "$GH/rbenv/rbenv-default-gems"
  sync_config_repo "$PLUGINS/rbenv-update"        "$GH/rkh/rbenv-update"
  sync_config_repo "$PLUGINS/rbenv-communal-gems" "$GH/tpope/rbenv-communal-gems"
  sync_config_repo "$PLUGINS/rbenv-user-gems"     "$GH/mislav/rbenv-user-gems"
  echo 'Done.'
}

pyenv_setup()
{
  blank_lines
  echo 'Installing pyenv...'
  local GH='https://github.com'
  local ROOT="$HOME/.pyenv"
  local PLUGINS="$ROOT/plugins"
  sync_config_repo "$ROOT"                     "$GH/pyenv/pyenv"
  sync_config_repo "$PLUGINS/pyenv-doctor"     "$GH/pyenv/pyenv-doctor"
  sync_config_repo "$PLUGINS/pyenv-update"     "$GH/pyenv/pyenv-update"
  sync_config_repo "$PLUGINS/pyenv-virtualenv" "$GH/pyenv/pyenv-virtualenv"
  sync_config_repo "$PLUGINS/pyenv-which-ext"  "$GH/pyenv/pyenv-which-ext"
  echo 'Done.'
}

nodenv_setup()
{
  blank_lines
  echo 'Installing nodenv...'
  local GH='https://github.com'
  local ROOT="$HOME/.nodenv"
  local PLUGINS="$ROOT/plugins"
  sync_config_repo "$ROOT"                               "$GH/nodenv/nodenv"
  sync_config_repo "$PLUGINS/node-build"                 "$GH/nodenv/node-build"
  sync_config_repo "$PLUGINS/nodenv-default-packages"    "$GH/nodenv/nodenv-default-packages"
  sync_config_repo "$PLUGINS/nodenv-package-json-engine" "$GH/nodenv/nodenv-package-json-engine"
  sync_config_repo "$PLUGINS/nodenv-package-rehash"      "$GH/nodenv/nodenv-package-rehash"
  sync_config_repo "$PLUGINS/nodenv-update"              "$GH/nodenv/nodenv-update"
  echo 'Done.'
}

goenv_setup()
{
  blank_lines
  echo 'Installing goenv...'
  local GH='https://github.com'
  local ROOT="$HOME/.goenv"
  local PLUGINS="$ROOT/plugins"
  sync_config_repo "$ROOT" "$GH/syndbg/goenv"
  echo 'Done.'
}

rustup_setup()
{
  blank_lines
  echo 'Installing rustup...'
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  echo 'Done.'
}

jenv_setup()
{
  blank_lines
  echo 'Installing jenv...'
  sync_config_repo ~/.jenv https://github.com/gcuisinier/jenv
  echo 'Done.'
}

util_setup()
{
  blank_lines
  printf 'Installing handy configs and wrappers... '
  backup_then_symlink "$config_dir/proxychains/proxychains.conf" ~/.config/proxychains.conf
  backup_then_symlink "$util_dir/shell/pyenv-install" ~/bin/pyenv-install
  backup_then_symlink "$util_dir/spark/pyspark-jupyter" ~/bin/pyspark-jupyter
  backup_then_symlink "$util_dir/spark/pyspark-jupyter-public" ~/bin/pyspark-jupyter-public
  echo 'Done.'
}

basic_env_setup()
{
  ssh_setup
  profile_setup
  bashit_setup
  zgen_setup
  tmux_setup
  git_setup
  tig_setup
  nodenv_setup
  pyenv_setup
  rbenv_setup
  goenv_setup
  rustup_setup
  vim_setup
}

extra_env_setup()
{
  jenv_setup
  util_setup

  install_common_packages
}

env_setup()
{
  basic_env_setup
  extra_env_setup
}

rime_setup()
{
  ( \
    mkdir -p "$HOME/tmp" && \
    cd "$HOME/tmp" && \
    curl -fsSL https://git.io/rime-install | bash -s -- jyutping emoji \
  )
}
