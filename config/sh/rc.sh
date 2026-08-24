export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export EDITOR='vim'

# Reset PATH to system default to avoid duplication from inherited environments (e.g. tmux)
PATH='/usr/bin:/bin:/usr/sbin:/sbin'

# Add flatpak directories to XDG_DATA_DIRS (user path takes precedence)
if is_linux; then
  export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
fi

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
export PATH="/usr/local/bin:$PATH"
if is_linux; then
  [ -d ~/.linuxbrew ] && eval "$(~/.linuxbrew/bin/brew shellenv)"
  [ -d /home/linuxbrew/.linuxbrew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  # nodenv cannot control global npm packages installed with linuxbrew node. Though `brew unlink node && brew link node`
  # can have all global npm packages linked to linuxbrew bin folder, it will be cumbersome to do unlink-link every time
  # a global npm package is installed.
  exists brew && [ -d "$(brew --prefix node)/bin" ] && export PATH="$(brew --prefix node)/bin:$PATH"
elif is_macos; then
  [ -d /opt/homebrew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# `brew shellenv` ends with `export FPATH`, which marks zsh's tied fpath EXPORTED.
# That leaks a *version-specific* fpath into child zsh processes — and the login
# shell here is the system zsh (5.7.1) while interactive shells are Homebrew zsh
# (5.9.2). The 5.9.2 shell inherits 5.7.1's completion dirs and never adds its own,
# so its `comparguments` builtin runs against 5.7.1 `_arguments`/`_cat` functions
# and completion dies with "_arguments:comparguments:NNN: not enough arguments"
# (e.g. on `cat <Tab>`). Repair: put THIS zsh's own version-matched function dir
# first so completion functions match the running binary, then drop the export
# flag so fpath stops leaking across zsh versions. The Cellar-path guard fires only
# when Homebrew ships a zsh of exactly the running version, so a system zsh run
# interactively keeps its own (already-correct) fpath untouched.
if [ -n "$ZSH_VERSION" ]; then
  if [ -n "$HOMEBREW_PREFIX" ] && [ -d "$HOMEBREW_PREFIX/Cellar/zsh/$ZSH_VERSION/share/zsh/functions" ]; then
    fpath=( "$HOMEBREW_PREFIX/Cellar/zsh/$ZSH_VERSION/share/zsh/functions" $fpath )
  fi
  typeset +x FPATH  # keep fpath process-local; never re-export it to children
fi

export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
export PATH="$PNPM_HOME:$PATH"
# Prepend goenv shims to PATH instead of appending
export GOENV_PATH_ORDER=front

# Homebrew
export HOMEBREW_NO_AUTO_UPDATE=1

# Use host OS IP as default proxy IP for WSL2
is_wsl2 && export WSL2_HOST_IP="$(cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }')"
export LOCAL_PROXY_IP="${WSL2_HOST_IP:-localhost}"

# Aliases

## Utils
alias cb=clipboard
alias n=nvim
alias ttmux='TERM=xterm-256color tmux'
# theme-sync (util/shell/theme-sync, on PATH via ~/.local/bin) reconciles the
# terminal's current light/dark theme to EVERY running tmux server and nvim
# instance at once — the manual hammer for terminals that don't push mode-2031.
# Back-compat alias for the old name (which only did the current tmux server).
alias tmux-theme-sync='theme-sync'
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

## AI coding agent related
export CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1
alias claude-yolo='claude --dangerously-skip-permissions'
alias codex-yolo='codex --yolo'
alias opencode-yolo='opencode --auto'

## Tools from npm
alias create-react-app='npx create-react-app'
alias react-native='npx react-native'
alias sb='npx -p @storybook/cli sb'
alias semantic-release-cli='npx semantic-release-cli'

if is_linux; then
  alias spath="PATH="$(echo ${PATH} | awk -v RS=: -v ORS=: '/home/ {next} {print}' | sed 's/:*$//')""
  alias audio-hdmi='pacmd set-card-profile 0 output:hdmi-stereo+input:analog-stereo'
  alias audio-laptop='pacmd set-card-profile 0 output:analog-stereo+input:analog-stereo'
  alias vnc-i3='VNC_DESKTOP_SESSION=i3 vncserver'
  alias vnc-xfce='VNC_DESKTOP_SESSION=xfce vncserver'
fi

# attempt to connect to existing ssh-agent instance on remote sessions
is_ssh && [ -f ~/.agent-profile ] && source ~/.agent-profile

# docker host patch for tools not respecting the current `docker context`
if exists docker; then
  alias dh="DOCKER_HOST=$(docker context inspect --format='{{.Endpoints.docker.Host}}')"
fi

# broot
broot_config=$(is_macos && echo "$HOME/Library/Preferences/org.dystroy.broot" || echo "$HOME/.config/broot")
if [ -f "$broot_config/launcher/bash/br" ]; then
  source "$broot_config/launcher/bash/br"
fi

# lf icons
[ -f ~/.config/lf/lf-icons.sh ] && source ~/.config/lf/lf-icons.sh

[ -f "$XDG_CONFIG_HOME/.rc.local" ] && source "$XDG_CONFIG_HOME/.rc.local"
