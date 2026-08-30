#!/bin/sh
# Bootstrap a fresh Termux install for SSH and tmux-based devbox access.

set -eu

if [ "${1:-}" = -h ] || [ "${1:-}" = --help ]; then
  cat <<'EOF'
Usage: termux.sh

Installs the basic Termux toolset, configures tmux-friendly extra keys, and
creates an SSH key. Configure Kerberos separately with: ./init kerberos
EOF
  exit 0
fi

[ "$#" -eq 0 ] || {
  printf '%s\n' 'termux-bootstrap: no arguments are supported; run ./init kerberos separately' >&2
  exit 2
}

command -v pkg >/dev/null 2>&1 || {
  printf '%s\n' 'termux-bootstrap: this script must run inside Termux' >&2
  exit 1
}

printf '%s\n' 'Updating Termux packages and installing the devbox toolset...'
pkg update -y
pkg install -y ca-certificates diff-so-fancy fzf git krb5 less nano openssh \
  python ripgrep tig tmux vim which zsh

repo_dir=$(unset CDPATH; cd "$(dirname "$0")/.." && pwd)
config_dir=$repo_dir/config
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
  "$XDG_CACHE_HOME" "$HOME/.local/bin"

link_config()
{
  link_source=$1
  link_target=$2
  mkdir -p "$(dirname "$link_target")"
  if [ -L "$link_target" ]; then
    rm -f "$link_target"
  elif [ -e "$link_target" ]; then
    if [ -e "$link_target.pre-dotfiles" ]; then
      printf 'termux-bootstrap: preserving existing %s; configure it manually\n' "$link_target" >&2
      return
    fi
    mv "$link_target" "$link_target.pre-dotfiles"
  fi
  ln -s "$link_source" "$link_target"
}

mkdir -p "$HOME/.termux" "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# A portable subset of the regular core setup. The shared shell profile is not
# linked because it resets PATH to desktop Unix paths that do not exist in
# Termux.
link_config "$config_dir/ssh/config" "$HOME/.ssh/config"
touch "$HOME/.ssh/config.local"
chmod 600 "$HOME/.ssh/config.local"
link_config "$config_dir/tmux" "$XDG_CONFIG_HOME/tmux"
link_config "$config_dir/tig" "$XDG_CONFIG_HOME/tig"
link_config "$config_dir/git/termux" "$XDG_CONFIG_HOME/git/config"
link_config "$repo_dir/util/shell/tmux-autoreload-launch" "$HOME/.local/bin/tmux-autoreload-launch"
link_config "$repo_dir/util/shell/tmux-appearance-fallback" "$HOME/.local/bin/tmux-appearance-fallback"
link_config "$repo_dir/util/shell/tmux-layout-keep-sidebar" "$HOME/.local/bin/tmux-layout-keep-sidebar"
link_config "$repo_dir/util/kerberos/kinit-auto-login" "$HOME/.local/bin/kinit-auto-login"
link_config "$repo_dir/util/kerberos/termux-kinit-shortcut" "$HOME/.local/bin/termux-kinit-shortcut"

termux_properties=$HOME/.termux/termux.properties
if [ -f "$termux_properties" ] && [ ! -f "$termux_properties.pre-bootstrap" ]; then
  cp "$termux_properties" "$termux_properties.pre-bootstrap"
fi
cat >"$termux_properties" <<'EOF'
# Termux does not support orientation-specific layouts, so stay at two rows in
# both portrait and landscape. Taps retain the default keys; swipe-up popups
# carry the remote tmux controls. The last key directly opens the SSH alias
# `termux-ssh-shortcut`, whose destination remains machine-local SSH config;
# swipe that key up to repair/renew the local Kerberos session.
extra-keys = [[{key: 'ESC', display: '⎋', popup: {key: '`', display: '`'}},'/',{key: '-', popup: '|'},{key: 'HOME', display: '↤', popup: {macro: '` ,', display: 'W‹'}},{key: 'UP', popup: {macro: '` n', display: 'A›'}},{key: 'END', display: '↦', popup: {macro: '` .', display: 'W›'}},{key: 'PGUP', display: '⇞', popup: {macro: '` v', display: '`v'}},{key: 'KEYBOARD', display: '⌨', popup: {macro: 'CTRL d', display: 'exit'}}], [{key: 'TAB', display: '⇥', popup: {macro: '` TAB', display: '▤'}},{key: 'CTRL', display: '⌃'},{key: 'ALT', display: '⌥'},{key: 'LEFT', popup: {macro: '` O', display: 'P‹'}},'DOWN',{key: 'RIGHT', popup: {macro: '` o', display: 'P›'}},{key: 'PGDN', display: '⇟', popup: {macro: '` p', display: '`p'}},{macro: 'ssh SPACE termux-ssh-shortcut ENTER', display: '▣', popup: {macro: 'termux-kinit-shortcut ENTER', display: 'K↻'}}]]
extra-keys-style = arrows-all
terminal-onclick-url-open = true
EOF
if command -v termux-reload-settings >/dev/null 2>&1; then
  termux-reload-settings
fi

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519"
fi

printf '\n%s\n' 'Termux bootstrap complete. Add this public key to the devbox:'
cat "$HOME/.ssh/id_ed25519.pub"
printf '\n%s\n' 'Next steps:'
printf '%s\n' '  ./init kerberos'
printf '%s\n' '  kinit-auto-login install --principal USER@BYTEDANCE.COM'
printf '%s\n' "  ssh -t USER@HOST 'tmux new-session -A -s main'"
