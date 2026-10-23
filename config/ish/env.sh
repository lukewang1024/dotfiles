# shellcheck shell=sh
# Environment shared by ash login and zsh on iSH.
export DOTFILES_PLATFORM=ish
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export KRB5_CONFIG="${KRB5_CONFIG:-$XDG_CONFIG_HOME/ish-kerberos/krb5.conf}"
export KRB5CCNAME="${KRB5CCNAME:-FILE:$XDG_CACHE_HOME/ish-kerberos/krb5cc}"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
