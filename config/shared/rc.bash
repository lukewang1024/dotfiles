export SHELL=bash

alias rrc='source ~/.bashrc'
alias ssh-agent-connect='source ~/.dotfiles/config/shared/ssh-agent-connect.bash'

# aliases to overwrite the ones defined in plugins
exists lsd && alias ls='lsd'
