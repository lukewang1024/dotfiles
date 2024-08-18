source "$config_dir/sh/xdg-ninja-patch.sh"

# zsh - .zcompdump
export ZGEN_CUSTOM_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION" # for zgen
# zsh - .zsh_history
export HISTFILE="$XDG_STATE_HOME/zsh/history"
