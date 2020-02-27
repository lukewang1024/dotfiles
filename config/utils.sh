# join array
join() { local IFS="$1"; shift; echo "$*"; }
join_by_multi() { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }

# command check
exists() { command -v "$1" >/dev/null 2>&1; }

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
is_cygwin() { is_os cygwin; }

is_ssh() { [ -n "$SSH_CLIENT" ]; }
is_tmux() { [ -n "$TMUX" ]; }
