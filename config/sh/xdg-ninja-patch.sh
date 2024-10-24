source "$config_dir/sh/xdg-paths.sh"

# android
export ANDROID_USER_HOME="$XDG_DATA_HOME/android"
alias adb='HOME="$XDG_DATA_HOME/android" adb'

# anyenv
export ANYENV_ROOT="$XDG_DATA_HOME/anyenv"

# cargo
export CARGO_HOME="$XDG_DATA_HOME/cargo"

# docker
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"

# gem
export GEM_HOME="$XDG_DATA_HOME/gem"
export GEM_SPEC_CACHE="$XDG_CACHE_HOME/gem"

# go
export GOPATH="$XDG_DATA_HOME/go"

# less
export LESSHISTFILE="$XDG_STATE_HOME/less/history"

# minikube
export MINIKUBE_HOME="$XDG_DATA_HOME/minikube"

# nb
export NB_DIR="$XDG_DATA_HOME/nb"
export NBRC_PATH="$XDG_CONFIG_HOME/nbrc"

# ncurses
export TERMINFO="$XDG_DATA_HOME/terminfo"
export TERMINFO_DIRS="$XDG_DATA_HOME/terminfo":/usr/share/terminfo

# nodejs
export NODE_COMPILE_CACHE="$XDG_CACHE_HOME/node_compile_cache"
export NODE_REPL_HISTORY="$XDG_DATA_HOME/node_repl_history"

# npm
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/npmrc"

# percol
alias percol='percol --rcfile=$XDG_CONFIG_HOME/percol/rc.py'

# python
# export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc"

# rustup
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"

# tldr
export TLDR_CACHE_DIR="$XDG_CACHE_HOME/tldr"

# w3m
export W3M_DIR="$XDG_DATA_HOME/w3m"

# wakatime
export WAKATIME_HOME="$XDG_CONFIG_HOME/wakatime"

# wget
alias wget='wget --hsts-file="$XDG_DATA_HOME/wget-hsts"'

# xonsh
alias xonsh='xonsh --rc "$XDG_CONFIG_HOME/xonsh/xonshrc"'

# xorg-xauth
export XAUTHORITY="$XDG_RUNTIME_DIR/Xauthority"

# zgen
export ZGEN_DIR="$XDG_DATA_HOME/zgen"
