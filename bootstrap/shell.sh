tmuxSetup()
{
  blankLines
  printf 'Symlinking tmux config files... '
  backupThenSymlink "$config_dir/tmux/.tmux.conf" ~/.tmux.conf
  echo 'Done.'
}

tigSetup()
{
  blankLines
  printf 'Symlinking .tigrc... '
  backupThenSymlink "$config_dir/tig/.tigrc" ~/.tigrc
  echo 'Done.'
}

vimSetup()
{
  printf 'Symlinking .vimrc... '
  backupThenSymlink "$config_dir/vim/.vimrc" ~/.vimrc
  echo 'Done.'

  echo 'Installing Vundle...'
  syncConfigRepo ~/.vim/bundle/Vundle.vim https://github.com/gmarik/Vundle.vim
  vim +PluginInstall +qall
  echo 'Done.'
}

sshSetup()
{
  blankLines
  printf 'Symlinking SSH config... '
  backupThenSymlink "$config_dir/ssh/config" ~/.ssh/config
  local localConfig="$HOME/.ssh/config.local"
  touch "$localConfig"
  chmod 644 "$localConfig"
  echo 'Done.'
}

zgenSetup()
{
  blankLines
  echo 'Setup zgen...'
  syncConfigRepo ~/.zgen https://github.com/tarjoilija/zgen
  echo 'Done.'

  printf 'Symlinking .zshrc... '
  backupThenSymlink "$config_dir/zgen/.zshrc" ~/.zshrc
  echo 'Done.'

  purePromptSetup
}

zplugSetup()
{
  blankLines
  echo 'Setup zplug...'
  if [ -d ~/.zplug ]; then
    syncConfigRepo ~/.zplug https://github.com/zplug/zplug
  else
    curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
  fi
  echo 'Done.'

  printf 'Symlinking .zshrc... '
  backupThenSymlink "$config_dir/zplug/.zshrc" ~/.zshrc
  echo 'Done.'

  purePromptSetup
}

purePromptSetup()
{
  blankLines
  echo 'Installing pure prompt...'
  yarn global add pure-prompt
  echo 'Done.'
}
