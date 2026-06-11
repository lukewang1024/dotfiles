tmux_setup()
{
  blank_lines
  printf 'Symlinking tmux config files... '
  backup_then_symlink "$config_dir/tmux" "$XDG_CONFIG_HOME/tmux"
  backup_then_symlink "$config_dir/tmux/tmux.conf" "$HOME/.tmux.conf" # hardcoded usage exists somewhere, so keep it
  # sesh smart session manager (driven from tmux via `prefix + T`)
  backup_then_symlink "$config_dir/sesh" "$XDG_CONFIG_HOME/sesh"
  backup_then_symlink "$util_dir/shell/sesh-connect" "$bin_dir/sesh-connect"
  # tmuxinator pool-config generator (writes machine-local ~/.config/tmuxinator/*.yml)
  backup_then_symlink "$util_dir/shell/gen-tmuxinator-configs" "$bin_dir/gen-tmuxinator-configs"
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
  printf 'Symlinking vim/nvim config (XDG)... '
  backup_then_symlink "$config_dir/vim" "$XDG_CONFIG_HOME/vim"
  backup_then_symlink "$config_dir/vim" "$XDG_CONFIG_HOME/nvim"
  echo 'Done.'

  echo 'Installing vim-plug...'
  curl -fLo "$XDG_DATA_HOME/vim/autoload/plug.vim" --create-dirs \
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

  echo "/etc/zshenv"
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

# Set up exactly one shell environment, since only one shell is typically used,
# and make it the default login shell. Defaults to zgen; select another via
# DOTFILES_SHELL or by calling zinit_setup / bashit_setup manually.
#   DOTFILES_SHELL=zgen  (default)
#   DOTFILES_SHELL=zinit
#   DOTFILES_SHELL=bash_it
shell_setup()
{
  case "${DOTFILES_SHELL:-zgen}" in
    'zgen')
      zgen_setup
      set_default_shell zsh
      ;;
    'zinit')
      zinit_setup
      set_default_shell zsh
      ;;
    'bash_it')
      bashit_setup
      set_default_shell bash
      ;;
    *)
      echo "Unknown DOTFILES_SHELL '$DOTFILES_SHELL', falling back to zgen."
      zgen_setup
      set_default_shell zsh
      ;;
  esac
}

set_default_shell()
{
  local shell_path="$(command -v "$1")"
  if [ -z "$shell_path" ]; then
    echo "Cannot find $1 in PATH, skip changing the default shell."
    return 1
  fi

  # Read the actual configured login shell from the user database, since $SHELL
  # only reflects the environment of the current session.
  local current_shell
  if command -v getent > /dev/null 2>&1; then
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  elif command -v dscl > /dev/null 2>&1; then
    current_shell="$(dscl . -read "/Users/$USER" UserShell 2> /dev/null | awk '{print $2}')"
  else
    current_shell="$SHELL"
  fi

  # Skip if the specified shell is already configured, regardless of which
  # install of it (e.g. /usr/bin/zsh vs brew zsh) the entry points to.
  if [ "$(basename "$current_shell")" = "$1" ]; then
    echo "Default shell is already $current_shell"
    return 0
  fi

  # The shell must be whitelisted in /etc/shells before chsh accepts it
  grep -qx "$shell_path" /etc/shells || echo "$shell_path" | sudo tee -a /etc/shells > /dev/null

  echo "Changing default shell to $shell_path..."
  chsh -s "$shell_path"
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
  # blank_lines
  # printf 'Symlinking .profile... '
  # backup_then_symlink "$config_dir/sh/.profile" ~/.profile
  # echo 'Done.'
  echo '.profile is skipped for symlinking.'
}
