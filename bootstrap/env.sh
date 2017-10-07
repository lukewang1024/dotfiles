source "$partial_dir/shell.sh"
source "$partial_dir/pkg.sh"

gitSetup()
{
  blankLines
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

nvmSetup()
{
  blankLines
  echo 'Installing nvm...'
  curl https://raw.githubusercontent.com/creationix/nvm/v0.33.2/install.sh | bash
  echo 'Done.'

  echo 'Installing latest LTS NodeJS...'
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  nvm install --lts
  echo 'Done.'
}

rbenvSetup()
{
  blankLines
  echo 'Installing rbenv...'
  curl https://raw.githubusercontent.com/fesplugas/rbenv-installer/master/bin/rbenv-installer | bash
  echo 'Done.'
}

pyenvSetup()
{
  blankLines
  echo 'Installing pyenv...'
  curl -L https://raw.githubusercontent.com/yyuu/pyenv-installer/master/bin/pyenv-installer | bash
  echo 'Done.'
}

utilSetup()
{
  blankLines
  printf 'Installing handy wrappers... '
  backupThenSymlink "$util_dir/spark/pyspark-jupyter" ~/bin/pyspark-jupyter
  backupThenSymlink "$util_dir/spark/pyspark-jupyter-public" ~/bin/pyspark-jupyter-public
  echo 'Done.'
}

envSetup()
{
  gitSetup
  nvmSetup
  rbenvSetup
  pyenvSetup
  tmuxSetup
  tigSetup
  vimSetup
  sshSetup
  zgenSetup
  utilSetup

  installCommonPackages
}

basicSetup()
{
  gitSetup
  tmuxSetup
  tigSetup
  vimSetup
  sshSetup
  zgenSetup
}
