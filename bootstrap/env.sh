gitSetup()
{
  blankLines
  echo 'Applying global git configs...'

  # Back up the current config file
  if [ -f ~/.gitconfig ]; then
    printf 'Backing up current .gitconfig... '
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
  read -p "Name to use in Git? " git_user_name
  read -p "Email to use in Git? " git_user_email
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
  curl https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | bash
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
