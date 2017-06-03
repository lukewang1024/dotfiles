tmuxSetup()
{
  blankLines
  print 'Symlinking tmux config files...'
  backupThenSymlink "$config_dir/tmux/.tmux.conf" ~/.tmux.conf
  echo 'Done.'
}

zgenSetup()
{
  blankLines
  echo 'Setup zgen...'
  if [ ! -d ~/.zgen ]; then
    echo 'Installing zgen...'
    git clone https://github.com/tarjoilija/zgen.git ~/.zgen
  else
    echo 'zgen already exists. Trying to update...'
    ( cd ~/.zgen; git pull )
  fi
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
  if [ ! -d ~/.zplug ]; then
    echo 'Installing zplug...'
    curl -sL --proto-redir -all,https https://zplug.sh/installer | zsh
  else
    echo 'zplug already exists. Trying to update...'
    ( cd ~/.zplug; git pull )
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
  npm install -g pure-prompt
  mkdir -p ~/bin
  ( \
    cd "$(dirname $(nvm which current))/../lib/node_modules/pure-prompt"; \
    ln -sf ./pure.zsh ~/bin/prompt_pure_setup; \
    ln -sf ./async.zsh ~/bin/async; \
  )
  echo 'Done.'
}
