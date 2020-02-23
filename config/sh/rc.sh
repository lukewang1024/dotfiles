export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export EDITOR='vim'

# Use xterm-256color when not in tmux
[[ $TMUX == '' ]] && export TERM='xterm-256color'

# Set ANDROID_HOME per platform
[[ $OSTYPE == 'darwin'* ]] && export ANDROID_HOME=$HOME/Library/Android/sdk
[[ $OSTYPE == 'linux-gnu' ]] && export ANDROID_HOME=$HOME/android-sdk && export I3FYRA_WS=1

# Use ripgrep with fzf
export FZF_DEFAULT_COMMAND='rg --files --follow --hidden'

# PATH
export PATH="/usr/bin/core_perl:$PATH"
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/bin:$PATH"
if [[ $OSTYPE == 'linux-gnu' ]]; then
  LINUXBREW='/home/linuxbrew/.linuxbrew'
  export PATH="$LINUXBREW/sbin:$PATH"
  export PATH="$LINUXBREW/bin:$PATH"
fi
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# Functions
exists()
{
  command -v "$1" >/dev/null 2>&1
}

# Aliases
alias cb=clipboard
alias n=nvim
alias sap='source ~/.agent-profile'
alias ap='all_proxy=socks5://localhost:1080'
alias ape='export all_proxy=socks5://localhost:1080'
alias apd='unset all_proxy'
alias hp='http_proxy=localhost:8123 https_proxy=localhost:8123'
alias hpe='export http_proxy=localhost:8123 https_proxy=localhost:8123'
alias hpd='unset http_proxy https_proxy'
alias px='proxychains4 -f ~/.config/proxychains.conf'
alias pq='proxychains4 -f ~/.config/proxychains.conf -q'
alias pping='prettyping --nolegend'
alias sshp='ssh -o PasswordAuthentication=yes'
alias sshcp='ssh-copy-id -o PasswordAuthentication=yes'
alias gitc='git --no-pager'
alias gmtf='git mergetool --no-prompt --tool=fugitive'

alias create-react-app='npx create-react-app'
alias react-native='npx react-native'
alias sb='npx -p @storybook/cli sb'
alias semantic-release-cli='npx semantic-release-cli'

if [[ $OSTYPE == 'linux-gnu' ]]; then
  alias audio-hdmi='pacmd set-card-profile 0 output:hdmi-stereo+input:analog-stereo'
  alias audio-laptop='pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo'
fi

[ -f ~/.config/lf/lf-icons.sh ] && source ~/.config/lf/lf-icons.sh

[ -f ~/.rc.local ] && source ~/.rc.local
