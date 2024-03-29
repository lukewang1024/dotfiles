# join array
join() { local IFS="$1"; shift; echo "$*"; }
join_by_multi() { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }

# command check
exists() { command -v "$1" >/dev/null 2>&1; }
string_contain() { [ -z "$1" ] || { [ -z "${2##*$1*}" ] && [ -n "$2" ]; }; }

# env check
is_os() { [[ $OSTYPE == *$1* ]]; }
is_nix() {
  local sys;
  case "$OSTYPE" in
    *linux*|*hurd*|*msys*|*cygwin*|*sua*|*interix*) sys='gnu';;
    *bsd*|*darwin*) sys='bsd';;
    *sunos*|*solaris*|*indiana*|*illumos*|*smartos*) sys='sun';;
  esac
  [[ "${sys}" == "$1" ]];
}

is_macos() { is_os darwin; }
is_linux() { is_os linux; }
is_wsl2() { [[ "$(uname -r | sed -n 's/.*\(WSL2\).*/\1/p')" == 'WSL2' ]]; }
is_cygwin() { is_os cygwin; }

is_ssh() { [ -n "$SSH_CLIENT" ]; }
is_tmux() { [ -n "$TMUX" ]; }
is_tty() { [[ "$(tty)" == /dev/tty* ]]; }
