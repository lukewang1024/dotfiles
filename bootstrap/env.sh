source "$partial_dir/shell.sh"
source "$partial_dir/pkg.sh"

git_setup()
{
  blank_lines
  echo 'Applying global git configs...'

  # Back up the current config file
  if [ -f ~/.gitconfig ]; then
    printf 'Backing up current .gitconfig... '
    git_user_name=`git config --global user.name`
    git_user_email=`git config --global user.email`
    mv ~/.gitconfig ~/.gitconfig~
    echo 'Done.'
  fi

  echo 'Applying new git configs...'
  cat "$config_dir/git/alias" > ~/.gitconfig
  cat "$config_dir/git/common" >> ~/.gitconfig

  # MacOS
  if [[ $OSTYPE == *'darwin'* ]]; then
    git config --global credential.helper osxkeychain
  fi

  # WSL & Cygwin
  uname -r | grep Microsoft &> /dev/null # returns 0 on WSL
  if [[ $? == 0 || $OSTYPE == 'cygwin' ]]; then
    git config --global core.autocrlf input
    git config --global core.fileMode false
  fi

  # Git user
  if [[ -n "$git_user_name" && -n "$git_user_email" ]]; then
    echo "Global user was configured as $git_user_name ($git_user_email) previously."
    read -p 'Press Y/y to configure it differently: ' -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo 'Configuring git user...'
      read -p "username: " git_user_name
      read -p "email: " git_user_email
    else
      echo "$git_user_name ($git_user_email) will be kept as the global user."
    fi
  else
    echo 'Configuring git user...'
    read -p "username: " git_user_name
    read -p "email: " git_user_email
  fi

  git config --global user.name "$git_user_name"
  git config --global user.email "$git_user_email"
  unset git_user_name
  unset git_user_email

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
  sync_config_repo "$PLUGINS/pyenv-installer"  "$GH/pyenv/pyenv-installer"
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

env_setup()
{
  git_setup
  rbenv_setup
  pyenv_setup
  nodenv_setup
  jenv_setup
  tmux_setup
  tig_setup
  vim_setup
  ssh_setup
  zgen_setup
  util_setup

  install_common_packages
}

basic_setup()
{
  git_setup
  tmux_setup
  tig_setup
  vim_setup
  ssh_setup
  zgen_setup
}
