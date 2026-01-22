source "$partial_dir/shell.sh"
source "$partial_dir/pkg.sh"
source "$config_dir/sh/xdg-ninja-patch.sh"

git_setup()
{
  blank_lines
  echo 'Applying global git configs...'

  mkdir -p "$XDG_CONFIG_HOME/git"

  # Back up the current config file
  if [ -f "$XDG_CONFIG_HOME/git/config" ]; then
    printf 'Backing up current $XDG_CONFIG_HOME/git/config... '
    local git_user_identities="$(git config --global --list | grep -E '^user\.\w+\.\w+=.+$')"
    mv "$XDG_CONFIG_HOME/git/config" "$XDG_CONFIG_HOME/git/config~"
    echo 'Done.'
  fi

  echo 'Applying new git configs...'
  cat "$config_dir/git/alias" > "$XDG_CONFIG_HOME/git/config"
  cat "$config_dir/git/common" >> "$XDG_CONFIG_HOME/git/config"
  [ -f "$config_dir/git/local" ] && cat "$config_dir/git/local" >> "$XDG_CONFIG_HOME/git/config"

  backup_then_symlink "$util_dir/shell/git-set-identity" "$bin_dir/git-set-identity"

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

anyenv_setup()
{
  anyenv install --init https://github.com/lukewang1024/anyenv-install.git
  anyenv install goenv
  anyenv install nodenv
  anyenv install pyenv
  anyenv install rbenv
  eval "$(anyenv init -)"

  local GH='https://github.com'

  local NODENV_PLUGINS="$(nodenv root)/plugins"
  sync_config_repo "$NODENV_PLUGINS/node-build"                 "$GH/nodenv/node-build"
  sync_config_repo "$NODENV_PLUGINS/nodenv-default-packages"    "$GH/nodenv/nodenv-default-packages"
  sync_config_repo "$NODENV_PLUGINS/nodenv-package-json-engine" "$GH/nodenv/nodenv-package-json-engine"
  sync_config_repo "$NODENV_PLUGINS/nodenv-package-rehash"      "$GH/nodenv/nodenv-package-rehash"
  sync_config_repo "$NODENV_PLUGINS/nodenv-update"              "$GH/nodenv/nodenv-update"

  local PYENV_PLUGINS="$(pyenv root)/plugins"
  sync_config_repo "$PYENV_PLUGINS/pyenv-doctor"     "$GH/pyenv/pyenv-doctor"
  sync_config_repo "$PYENV_PLUGINS/pyenv-update"     "$GH/pyenv/pyenv-update"
  sync_config_repo "$PYENV_PLUGINS/pyenv-virtualenv" "$GH/pyenv/pyenv-virtualenv"
  sync_config_repo "$PYENV_PLUGINS/pyenv-which-ext"  "$GH/pyenv/pyenv-which-ext"

  local RBENV_PLUGINS="$(rbenv root)/plugins"
  sync_config_repo "$RBENV_PLUGINS/ruby-build"          "$GH/rbenv/ruby-build"
  sync_config_repo "$RBENV_PLUGINS/rbenv-vars"          "$GH/rbenv/rbenv-vars"
  sync_config_repo "$RBENV_PLUGINS/rbenv-each"          "$GH/rbenv/rbenv-each"
  sync_config_repo "$RBENV_PLUGINS/rbenv-default-gems"  "$GH/rbenv/rbenv-default-gems"
  sync_config_repo "$RBENV_PLUGINS/rbenv-update"        "$GH/rkh/rbenv-update"
  sync_config_repo "$RBENV_PLUGINS/rbenv-communal-gems" "$GH/tpope/rbenv-communal-gems"
  sync_config_repo "$RBENV_PLUGINS/rbenv-user-gems"     "$GH/mislav/rbenv-user-gems"
}

rustup_setup()
{
  blank_lines
  echo 'Installing rustup...'
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  echo 'Done.'
}

python_setup()
{
  blank_lines
  printf 'Symlinking pythonrc... '
  backup_then_symlink "$config_dir/python" "$XDG_CONFIG_HOME/python"
  touch "$XDG_STATE_HOME/python_history"
  echo 'Done.'
}

npm_setup()
{
  blank_lines
  local npmrc="$XDG_CONFIG_HOME/npm/npmrc"

  # Back up the current config file
  if [ -f "$npmrc" ]; then
    printf "Backing up current ${npmrc}... "
    mv "$npmrc" "$npmrc~"
    echo 'Done.'
  fi

  echo 'Applying new npmrc...'
  cat "$config_dir/npm/common" > "$npmrc"
  [ -f "$config_dir/npm/local" ] && cat "$config_dir/npm/local" >> "$npmrc"
  echo 'Done.'
}

util_setup()
{
  blank_lines
  printf 'Installing handy configs and wrappers... '
  backup_then_symlink "$config_dir/proxychains/proxychains.conf" "$XDG_CONFIG_HOME/proxychains.conf"
  backup_then_symlink "$util_dir/agent/claude-notify-stop" "$bin_dir/claude-notify-stop"
  backup_then_symlink "$util_dir/spark/pyspark-jupyter" "$bin_dir/pyspark-jupyter"
  backup_then_symlink "$util_dir/spark/pyspark-jupyter-public" "$bin_dir/pyspark-jupyter-public"
  echo 'Done.'
}

basic_env_setup()
{
  profile_setup
  bashit_setup
  zgen_setup
  ssh_setup
  tmux_setup
  git_setup
  tig_setup
  anyenv_setup
  rustup_setup
  npm_setup
  vim_setup
  xdg_dir_create
}

xdg_dir_create()
{
  printf 'Creating XDG state & cache directories...'
  # bash
  mkdir -p "$XDG_STATE_HOME/bash"
  # less
  mkdir -p "$XDG_STATE_HOME/less"
  # npm
  mkdir -p "$XDG_CONFIG_HOME/npm"
  mkdir -p "$XDG_DATA_HOME/npm"
  mkdir -p "$XDG_CACHE_HOME/npm"
  mkdir -p "$XDG_STATE_HOME/npm/logs"
  # tldr
  mkdir -p "$XDG_CACHE_HOME/tldr"
  # wakatime
  mkdir -p "$XDG_CONFIG_HOME/wakatime"
  # zsh
  mkdir -p "$XDG_CACHE_HOME/zsh"
  mkdir -p "$XDG_STATE_HOME/zsh"
  echo 'Done.'
}

extra_env_setup()
{
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
