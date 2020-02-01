# Launch tmux on remote session
[ -n "$SSH_CLIENT" ] && [ -z "$TMUX" ] && tmux

# Load customized p10k prompt
[ -f "$zsh_config_dir/.p10k.zsh" ] && source "$zsh_config_dir/.p10k.zsh"
