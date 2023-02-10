export SHELL=bash

alias rrc='source ~/.bashrc'
alias ssh-agent-connect="source $config_dir/bash/ssh-agent-connect.bash"

exists zoxide && eval "$(zoxide init bash)"
exists starship && eval "$(starship init bash)"

# aliases to overwrite the ones defined in plugins
exists lsd && alias ls='lsd'
exists lsd && alias tree='lsd --tree'
