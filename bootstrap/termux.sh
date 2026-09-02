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
pkg install -y ca-certificates curl diff-so-fancy fzf git krb5 less nano openssh \
  python ripgrep tig tmux vim which zsh

repo_dir=$(unset CDPATH; cd "$(dirname "$0")/.." && pwd)
config_dir=$repo_dir/config
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
  "$XDG_CACHE_HOME" "$HOME/.local/bin"
case :$PATH: in
  *:"$HOME/.local/bin":*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

ensure_local_bin_path()
{
  shell_rc=$1
  marker='# >>> dotfiles Termux local bin >>>'
  touch "$shell_rc"
  grep -qF "$marker" "$shell_rc" 2>/dev/null && return
  cat >>"$shell_rc" <<'EOF'

# >>> dotfiles Termux local bin >>>
case ":$PATH:" in
  *:"$HOME/.local/bin":*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
# <<< dotfiles Termux local bin <<<
EOF
}

ensure_local_bin_path "$HOME/.bashrc"
ensure_local_bin_path "$HOME/.zshrc"

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
link_config "$repo_dir/util/shell/ssh-connect" "$HOME/.local/bin/ssh-connect"
link_config "$repo_dir/util/kerberos/kinit-auto-login" "$HOME/.local/bin/kinit-auto-login"
link_config "$repo_dir/util/kerberos/termux-kinit-shortcut" "$HOME/.local/bin/termux-kinit-shortcut"

link_config "$config_dir/termux/termux.properties" "$HOME/.termux/termux.properties"
link_config "$config_dir/termux/colors.properties" "$HOME/.termux/colors.properties"

# Termux supports one custom font at ~/.termux/font.ttf. Keep the large binary
# out of git: cache a pinned MesloLGS Nerd Font release and link only the path
# Termux hard-codes. The checksum makes a partial or changed download fail
# closed instead of leaving the terminal with a corrupt font.
font_dir=$XDG_CACHE_HOME/termux/fonts
font_file=$font_dir/MesloLGS-NF-Regular.ttf
font_sha256=d97946186e97f8d7c0139e8983abf40a1d2d086924f2c5dbf1c29bd8f2c6e57d
font_url=https://raw.githubusercontent.com/romkatv/powerlevel10k-media/145eb9fbc2f42ee408dacd9b22d8e6e0e553f83d/MesloLGS%20NF%20Regular.ttf
mkdir -p "$font_dir"
if ! printf '%s  %s\n' "$font_sha256" "$font_file" | sha256sum -c - >/dev/null 2>&1; then
  font_tmp=$font_file.tmp.$$
  trap 'rm -f "$font_tmp"' EXIT HUP INT TERM
  printf '%s\n' 'Downloading MesloLGS Nerd Font for Termux...'
  curl --proto '=https' --tlsv1.2 -fL --retry 3 -o "$font_tmp" "$font_url"
  printf '%s  %s\n' "$font_sha256" "$font_tmp" | sha256sum -c - >/dev/null
  mv "$font_tmp" "$font_file"
  trap - EXIT HUP INT TERM
fi
link_config "$font_file" "$HOME/.termux/font.ttf"
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
printf '%s\n' '  ssh-connect hosts edit --discover'
printf '%s\n' '  ssh-connect'
