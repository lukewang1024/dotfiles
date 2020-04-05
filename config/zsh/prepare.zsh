# Config ssh-agent on local machine
! is_ssh && source "$zsh_config_dir/ssh-agent-connect.zsh"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block, everything else may go below.
p10k_instant_prompt_path="${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"

# tty command will return "not a tty" if instant prompt is enabled, which will
# break the check for /dev/tty1 later in profile.sh.
# Disable it if it is running on a tty-type terminal.
if ! is_tty && [[ -r "$p10k_instant_prompt_path" ]]; then
  source "$p10k_instant_prompt_path"
fi

unset p10k_instant_prompt_path
