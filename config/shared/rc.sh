export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export EDITOR='vim'

# Use xterm-256color when not in tmux
[[ $TMUX == '' ]] && export TERM='xterm-256color'

# Set ANDROID_HOME per platform
[[ $OSTYPE == *'darwin'* ]] && export ANDROID_HOME=$HOME/Library/Android/sdk
[[ $OSTYPE == 'linux-gnu' ]] && export ANDROID_HOME=$HOME/android-sdk

# PATH
export PATH="/usr/bin/core_perl:$PATH"
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/bin:$PATH"
if [[ $OSTYPE == 'linux-gnu' ]]; then
  LINUXBREW='/home/linuxbrew/.linuxbrew'
  export PATH="$LINUXBREW/sbin:$PATH"
  export PATH="$LINUXBREW/bin:$PATH"
fi
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# Aliases
alias cb=clipboard
alias sap='source ~/.agent-profile'
alias hp='http_proxy=localhost:8123 https_proxy=localhost:8123'
alias hpe='export http_proxy=localhost:8123 https_proxy=localhost:8123'
alias hpd='unset http_proxy https_proxy'
alias px='proxychains4 -f ~/.config/proxychains.conf'
alias pq='proxychains4 -f ~/.config/proxychains.conf -q'
alias sshp='ssh -o PasswordAuthentication=yes'
alias sshcp='ssh-copy-id -o PasswordAuthentication=yes'
alias gitc='git --no-pager'

if [[ $OSTYPE == 'linux-gnu' ]]; then
  alias xcape-mod='xcape -e "Control_L=Escape;Mode_switch=Escape"'
  alias audio-hdmi='pacmd set-card-profile 0 output:hdmi-stereo+input:analog-stereo'
  alias audio-laptop='pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo'
fi

[ -f ~/.rc.local ] && source ~/.rc.local
