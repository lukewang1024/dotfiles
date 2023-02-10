# Launch tmux on remote session
is_ssh && ! is_tmux && tmux

source "$config_dir/sh/profile.sh"

# Load customized p10k prompt
exists p10k && [ -f "$zsh_config_dir/.p10k.zsh" ] && source "$zsh_config_dir/.p10k.zsh"
