# Config ssh-agent on local machine
! is_ssh && source "$config_dir/zsh/ssh-agent-connect.zsh"

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

# The default `pyenv virtualenv-init -` in pyenv plugin could slow down prompt
# drastically. Disable it.
ZSH_PYENV_VIRTUALENV=false

# oh-my-zsh runs compinit for us. Skip its compaudit security scan (compfix): on a
# personal machine it's safe, and it cuts the occasional compdump *rebuild* from
# ~13s to ~2s. Normal warm startups already reuse the cached dump (~40ms) regardless.
ZSH_DISABLE_COMPFIX=true
