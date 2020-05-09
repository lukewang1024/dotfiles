export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export EDITOR='vim'

# Use xterm-256color when not in tmux
! is_tmux && export TERM='xterm-256color'

# Set ANDROID_HOME per platform
is_macos && export ANDROID_HOME=$HOME/Library/Android/sdk
is_linux && export ANDROID_HOME=$HOME/android-sdk

is_linux && export I3FYRA_WS=1

# Use ripgrep with fzf
export FZF_DEFAULT_COMMAND='rg --files --follow --hidden'

# PATH
export PATH="/usr/bin/core_perl:$PATH"
export PATH="/usr/local/sbin:$PATH"
export PATH="/usr/local/bin:$PATH"
if is_linux; then
  LINUXBREW='/home/linuxbrew/.linuxbrew'
  export PATH="$LINUXBREW/sbin:$PATH"
  export PATH="$LINUXBREW/bin:$PATH"
fi
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/bin:$PATH"

# Aliases

## Utils
alias cb=clipboard
alias n=nvim
alias pping='prettyping --nolegend'

## SSH related
alias sap='source ~/.agent-profile'
alias sshp='ssh -o PasswordAuthentication=yes'
alias sshcp='ssh-copy-id -o PasswordAuthentication=yes'

## Proxy related
alias ap='all_proxy=socks5://localhost:1080'
alias apd='unset all_proxy'
alias ape='export all_proxy=socks5://localhost:1080'
alias hp='http_proxy=localhost:8123 https_proxy=localhost:8123'
alias hpd='unset http_proxy https_proxy'
alias hpe='export http_proxy=localhost:8123 https_proxy=localhost:8123'
alias pq='proxychains4 -f ~/.config/proxychains.conf -q'
alias px='proxychains4 -f ~/.config/proxychains.conf'

## Git related
alias gitc='git --no-pager'
alias gmtf='git mergetool --no-prompt --tool=fugitive'
alias tigall='TIGRC_USER=~/.config/tig/config_all tig'

## Npx tools
alias create-react-app='npx create-react-app'
alias react-native='npx react-native'
alias sb='npx -p @storybook/cli sb'
alias semantic-release-cli='npx semantic-release-cli'

if is_linux; then
  alias audio-hdmi='pacmd set-card-profile 0 output:hdmi-stereo+input:analog-stereo'
  alias audio-laptop='pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo'
fi

# attempt to connect to existing ssh-agent instance on remote sessions
is_ssh && [ -f ~/.agent-profile ] && source ~/.agent-profile

# broot
broot_config=$(is_macos && echo "$HOME/Library/Preferences/org.dystroy.broot" || echo "$HOME/.config/broot")
if [ -f "$broot_config/launcher/bash/br" ]; then
  source "$broot_config/launcher/bash/br"
fi

# lf icons
[ -f ~/.config/lf/lf-icons.sh ] && source ~/.config/lf/lf-icons.sh

[ -f ~/.rc.local ] && source ~/.rc.local
