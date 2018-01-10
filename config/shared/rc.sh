export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export EDITOR='vim'

# Use xterm-256color when not in tmux
[[ $TMUX == '' ]] && export TERM='xterm-256color'

# PATH
export PATH="/usr/bin/core_perl:$PATH"
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/bin:$PATH"
if [[ $OSTYPE == 'linux-gnu' ]]; then
  export PATH="/home/linuxbrew/.linuxbrew/sbin:$PATH"
  export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
fi
export PATH="$HOME/bin:$PATH"

# Aliases
alias cb=clipboard
alias sap='source ~/.agent-profile'
alias hp='http_proxy=localhost:8123 https_proxy=localhost:8123'
alias hpe='export http_proxy=localhost:8123 https_proxy=localhost:8123'
alias hpd='unset http_proxy https_proxy'
alias px='proxychains4 -f ~/.config/proxychains.conf'
alias pq='proxychains4 -f ~/.config/proxychains.conf -q'

# Functions

# Locate directly to a subsection in man page
mann () {
  man $1 | less -p "^( |\t){0,8}$2 "
}

[ -f ~/.rc.local ] && source ~/.rc.local
