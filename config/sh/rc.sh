export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export EDITOR='vim'

# Use xterm-256color for non-tmux remote session
is_ssh && ! is_tmux && export TERM='xterm-256color'

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
  [ -d ~/.linuxbrew ] && eval "$(~/.linuxbrew/bin/brew shellenv)"
  [ -d /home/linuxbrew/.linuxbrew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif is_macos; then
  [ -d /opt/homebrew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Use host OS IP as default proxy IP for WSL2
is_wsl2 && export WSL2_HOST_IP="$(cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }')"
export LOCAL_PROXY_IP="${WSL2_HOST_IP:-localhost}"

# pyenv
if [ -d "$HOME/.pyenv" ]; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init --path)"
fi

# Aliases

## Utils
alias cb=clipboard
alias n=nvim
alias ttmux='TERM=xterm-256color tmux'
alias pping='prettyping --nolegend'
alias ports='lsof -iTCP -sTCP:LISTEN -P'
alias upenv='nodenv update && pyenv update && rbenv update && vim +PlugUpgrade +PlugUpdate +qa'

## SSH related
alias sap='source ~/.agent-profile'
alias sshp='ssh -o PasswordAuthentication=yes'
alias sshcp='ssh-copy-id -o PasswordAuthentication=yes'

## Proxy related
alias ap="all_proxy=socks5://${LOCAL_PROXY_IP}:1080"
alias apd='unset all_proxy'
alias ape="export all_proxy=socks5://${LOCAL_PROXY_IP}:1080"
alias hp="http_proxy=${LOCAL_PROXY_IP}:1081 https_proxy=${LOCAL_PROXY_IP}:1081"
alias hpd='unset http_proxy https_proxy'
alias hpe="export http_proxy=${LOCAL_PROXY_IP}:1081 https_proxy=${LOCAL_PROXY_IP}:1081"
alias pq='proxychains4 -f ~/.config/proxychains.conf -q'
alias px='proxychains4 -f ~/.config/proxychains.conf'

## Git related
alias gitc='git --no-pager'
alias gmtlg='git mergetool --no-prompt --gui'
alias tigall='TIGRC_USER=~/.config/tig/config_all tig'

## Tools from npm
alias create-react-app='npx create-react-app'
alias react-native='npx react-native'
alias sb='npx -p @storybook/cli sb'
alias semantic-release-cli='npx semantic-release-cli'

if is_linux; then
  alias spath="PATH="$(echo ${PATH} | awk -v RS=: -v ORS=: '/home/ {next} {print}' | sed 's/:*$//')""
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

[ -f "$XDG_CONFIG_HOME/.rc.local" ] && source "$XDG_CONFIG_HOME/.rc.local"
