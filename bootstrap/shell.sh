tmux_setup()
{
  blank_lines
  printf 'Symlinking tmux config files... '
  backup_then_symlink "$config_dir/tmux" "$XDG_CONFIG_HOME/tmux"
  backup_then_symlink "$config_dir/tmux/tmux.conf" "$HOME/.tmux.conf" # hardcoded usage exists somewhere, so keep it
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
  sync_config_repo "$XDG_DATA_HOME/zgen" https://github.com/tarjoilija/zgen
  echo 'Done.'

  printf 'Symlinking .zprofile and .zshrc... '
  backup_then_symlink "$config_dir/zsh/zgen.zshrc" "$XDG_CONFIG_HOME/zsh/.zshrc"
  zsh_common_setup
  echo 'Done.'
}

zinit_setup()
{
  blank_lines
  echo 'Setup zinit...'
  sync_config_repo "$XDG_DATA_HOME/zinit/zinit.git" https://github.com/zdharma-continuum/zinit.git
  echo 'Done.'

  printf 'Symlinking .zprofile and .zshrc... '
  backup_then_symlink "$config_dir/zsh/zinit.zshrc" "$XDG_CONFIG_HOME/zsh/.zshrc"
  zsh_common_setup
  echo 'Done.'
}

# Function to check common global zshenv locations
find_global_zshenv() {
  local locations=(
    "/etc/zshenv"
    "/etc/zsh/zshenv"
    "/usr/local/etc/zshenv"
  )

  for loc in "${locations[@]}"; do
    if [ -f "$loc" ]; then
      echo "$loc"
      return 0
    fi
  done

  # If no file found, try to get from zsh itself
  if command -v zsh >/dev/null 2>&1; then
    # Try to get global zshenv path from zsh
    local zsh_path=$(zsh -c 'echo $ZSHENV')
    if [ -f "$zsh_path" ]; then
      echo "$zsh_path"
      return 0
    fi
  fi

  return 1
}

zsh_common_setup()
{
  # Use $HOME/.config since $XDG_CONFIG_HOME might be undefined at /etc/zshenv.
  ZDOTENV_EXPORT='export ZDOTDIR="$HOME/.config/zsh"'
  local globalZshEnv="$(find_global_zshenv)"
  if [ -f $globalZshEnv ] && grep -wq "$ZDOTENV_EXPORT" "$globalZshEnv"; then
    echo "ZDOTENV exists in $globalZshEnv"
  else
    echo "$ZDOTENV_EXPORT" | sudo tee -a "$globalZshEnv" > /dev/null
    echo "ZDOTENV set in $globalZshEnv"
  fi

  backup_then_symlink "$config_dir/zsh/.zlogin" "$XDG_CONFIG_HOME/zsh/.zlogin"
  backup_then_symlink "$config_dir/zsh/.zshenv" "$XDG_CONFIG_HOME/zsh/.zshenv"
  backup_then_symlink "$config_dir/zsh/.zprofile" "$XDG_CONFIG_HOME/zsh/.zprofile"
  backup_then_symlink "$config_dir/zsh/.p10k.zsh" "$XDG_CONFIG_HOME/zsh/.p10k.zsh"
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
