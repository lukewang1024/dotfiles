export LANG=en_US.UTF-8
export EDITOR='vim'

# Use xterm-256color when not in tmux
[[ $TMUX == '' ]] && export TERM='xterm-256color'

# PATH
export PATH=/usr/bin/core_perl:$PATH
export PATH=/usr/local/bin:$PATH
export MANPATH=/usr/local/man:$MANPATH
if [[ $OSTYPE == 'linux-gnu' ]]; then
  export PATH=$HOME/.linuxbrew/bin:$PATH
  export MANPATH=$HOME/.linuxbrew/share/man:$MANPATH
  export INFOPATH=$HOME/.linuxbrew/share/info:$INFOPATH
fi
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/.yarn/bin:$PATH
export PATH=$HOME/bin:$PATH
