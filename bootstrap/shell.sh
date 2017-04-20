zgenSetup()
{
  blankLines
  echo 'Setup zgen...'
  if [ ! -d ~/.zgen ]; then
    echo 'Installing zgen...'
    git clone https://github.com/tarjoilija/zgen.git ~/.zgen
    echo 'Done.'
  fi

  printf 'Symlinking .zshrc... '
  backupThenSymlink "$config_dir/zgen/.zshrc" ~/.zshrc
  echo 'Done.'
}

zplugSetup()
{
  blankLines
  echo 'Setup zplug...'
  if [ ! -d ~/.zplug ]; then
    echo 'Installing zplug...'
    curl -sL --proto-redir -all,https https://zplug.sh/installer | zsh
    echo 'Done.'
  else
    echo 'zplug already exists.'
  fi

  printf 'Symlinking .zshrc... '
  backupThenSymlink "$config_dir/zplug/.zshrc" ~/.zshrc
  echo 'Done.'
}
