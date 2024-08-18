export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

is_macos && export XDG_RUNTIME_DIR="$HOME/.cache/run"
is_linux && export XDG_RUNTIME_DIR="/run/user/$UID"
