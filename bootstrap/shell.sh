tmux_setup()
{
  blank_lines
  printf 'Symlinking tmux config files... '
  backup_then_symlink "$config_dir/tmux/.tmux.conf" ~/.tmux.conf
  echo 'Done.'
}

tig_setup()
{
  blank_lines
  printf 'Symlinking .tigrc... '
  backup_then_symlink "$config_dir/tig/.tigrc" ~/.tigrc
  echo 'Done.'
}

vim_setup()
{
  printf 'Symlinking .vimrc... '
  backup_then_symlink "$config_dir/vim/.vimrc" ~/.vimrc
  echo 'Done.'

  echo 'Installing Vundle...'
  sync_config_repo ~/.vim/bundle/Vundle.vim https://github.com/gmarik/Vundle.vim
  vim +PluginInstall +qall
  echo 'Done.'
}

ssh_setup()
{
  blank_lines
  printf 'Symlinking SSH config... '
  backup_then_symlink "$config_dir/ssh/config" ~/.ssh/config
  local localConfig="$HOME/.ssh/config.local"
  touch "$localConfig"
  chmod 644 "$localConfig"
  echo 'Done.'
}

zgen_setup()
{
  blank_lines
  echo 'Setup zgen...'
  sync_config_repo ~/.zgen https://github.com/tarjoilija/zgen
  echo 'Done.'

  printf 'Symlinking .zprofile and .zshrc... '
  backup_then_symlink "$config_dir/shared/.zprofile" ~/.zprofile
  backup_then_symlink "$config_dir/zgen/.zshrc" ~/.zshrc
  echo 'Done.'

  pure_prompt_setup
}

zplug_setup()
{
  blank_lines
  echo 'Setup zplug...'
  if [ -d ~/.zplug ]; then
    sync_config_repo ~/.zplug https://github.com/zplug/zplug
  else
    curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
  fi
  echo 'Done.'

  printf 'Symlinking .zprofile and .zshrc... '
  backup_then_symlink "$config_dir/shared/.zprofile" ~/.zprofile
  backup_then_symlink "$config_dir/zplug/.zshrc" ~/.zshrc
  echo 'Done.'

  pure_prompt_setup
}

bashit_setup()
{
  blank_lines
  echo 'Setup bash-it...'
  sync_config_repo ~/.bash_it https://github.com/Bash-it/bash-it
  ~/.bash_it/install.sh --no-modify-config
  echo 'Done.'

  printf 'Symlinking .bash_profile and .bashrc... '
  backup_then_symlink "$config_dir/bash_it/.bash_profile" ~/.bash_profile
  backup_then_symlink "$config_dir/bash_it/.bashrc" ~/.bashrc
  echo 'Done.'

  # Enable common plugins
  bash -i -c ' \
    bash-it enable alias      ag general git tmux; \
    bash-it enable plugin     alias-completion base extract fasd git jenv less-pretty-cat nodenv pyenv rbenv tmux; \
    bash-it enable completion bash-it brew conda git git_flow_avh npm ssh system tmux; \
    exit'
}

pure_prompt_setup()
{
  blank_lines
  echo 'Installing pure prompt...'
  npm install -g pure-prompt
  echo 'Done.'
}
