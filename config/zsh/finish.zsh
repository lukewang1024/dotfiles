# Launch tmux on remote session
is_ssh && ! is_tmux && tmux

source "$config_dir/sh/profile.sh"

exists anyenv && eval "$(anyenv init -)"

# Load pyenv-virtualenv properly
# https://github.com/pyenv/pyenv-virtualenv/issues/259#issuecomment-1096144748
exists pyenv && eval "$(pyenv virtualenv-init - | sed s/precmd/chpwd/g)"

# Load customized p10k prompt
exists p10k && [ -f "${ZDOTDIR:-~}/.p10k.zsh" ] && source "${ZDOTDIR:-~}/.p10k.zsh"
