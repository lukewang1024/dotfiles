nvmSetup()
{
  blankLines
  echo 'Installing nvm...'
  curl https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | bash
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
