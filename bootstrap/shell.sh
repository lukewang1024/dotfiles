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
  backup_then_symlink "$config_dir/tig" ~/.config/tig
  echo 'Done.'
}

vim_setup()
{
  printf 'Symlinking .vimrc... '
  backup_then_symlink "$config_dir/vim/.vimrc" ~/.vimrc
  backup_then_symlink "$config_dir/nvim/coc-settings.json" ~/.vim/coc-settings.json
  backup_then_symlink "$config_dir/nvim" ~/.config/nvim
  echo 'Done.'

  echo 'Installing vim-plug...'
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  vim +PlugInstall +qa
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
  backup_then_symlink "$config_dir/zsh/zgen.zshrc" ~/.zshrc
  backup_then_symlink "$config_dir/zsh/.zlogin" ~/.zlogin
  backup_then_symlink "$config_dir/zsh/.p10k.zsh" ~/.p10k.zsh
  echo 'Done.'
}

zinit_setup()
{
  blank_lines
  echo 'Setup zinit...'
  if [ -d ~/.zinit ]; then
    sync_config_repo ~/.zinit/bin https://github.com/zdharma/zinit
  else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"
  fi
  echo 'Done.'

  printf 'Symlinking .zprofile and .zshrc... '
  backup_then_symlink "$config_dir/zsh/zinit.zshrc" ~/.zshrc
  backup_then_symlink "$config_dir/zsh/.zlogin" ~/.zlogin
  backup_then_symlink "$config_dir/zsh/.p10k.zsh" ~/.p10k.zsh
  echo 'Done.'
}

bashit_setup()
{
  blank_lines
  echo 'Setup bash-it...'
  sync_config_repo ~/.bash_it https://github.com/Bash-it/bash-it
  ~/.bash_it/install.sh --no-modify-config
  echo 'Done.'

  printf 'Symlinking .bash_profile and .bashrc... '
  backup_then_symlink "$config_dir/bash/bash_it.bash_profile" ~/.bash_profile
  backup_then_symlink "$config_dir/bash/bash_it.bashrc" ~/.bashrc
  echo 'Done.'

  # Enable common plugins
  bash -i -c ' \
    bash-it enable alias      ag general git tmux; \
    bash-it enable plugin     alias-completion base extract git jenv less-pretty-cat nodenv pyenv rbenv tmux; \
    bash-it enable completion bash-it brew conda git git_flow_avh npm ssh system tmux; \
    exit'
}

profile_setup()
{
  blank_lines
  printf 'Symlinking .profile... '
  backup_then_symlink "$config_dir/sh/.profile" ~/.profile
  echo 'Done.'
}
