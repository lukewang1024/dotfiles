#!/bin/sh
# Shared POSIX helpers. Never source user configuration as shell code.
die() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
setup_paths() {
    umask 077
    export LC_ALL=C
    CONF_DIR=${ISH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/ish-kerberos}
    CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/ish-kerberos
    KRB5_CONFIG=${KRB5_CONFIG:-$CONF_DIR/krb5.conf}
    KRB5CCNAME=${KRB5CCNAME:-FILE:$CACHE_DIR/krb5cc}
    export KRB5_CONFIG KRB5CCNAME
}
load_config() {
    setup_paths
    [ -r "$CONF_DIR/user.conf" ] || die 'Missing user.conf; run ./init core, then ./init kerberos.'
    KRB5_REALM='' KRB5_PRINCIPAL='' KDC_HOST='' SSH_HOST='' SSH_USER=''
    KDC_PORT=88 SSH_PORT=22 TMUX_SESSION=dev
    # BusyBox read polls regular files; upstream Linux iSH can wait forever on
    # that path (epoll rejects regular files). cat + newline-only splitting
    # avoids it while still treating configuration strictly as data.
    config_lines=$(cat "$CONF_DIR/user.conf") || die 'Cannot read user.conf.'
    saved_ifs=$IFS
    IFS='
'
    case $- in *f*) restore_glob=no ;; *) restore_glob=yes; set -f ;; esac
    for line in $config_lines; do
        case "$line" in ''|'#'*) continue ;; esac
        case "$line" in *=*) ;; *) die 'Invalid user.conf line; use KEY=value without quotes.' ;; esac
        key=${line%%=*}; val=${line#*=}
        case "$val" in ''|*[!a-zA-Z0-9_@./:+-]*) die 'Invalid configuration value (spaces, quotes and shell expressions are not supported).' ;; esac
        case "$key" in
            KRB5_REALM) KRB5_REALM=$val ;; KRB5_PRINCIPAL) KRB5_PRINCIPAL=$val ;;
            KDC_HOST) KDC_HOST=$val ;; KDC_PORT) KDC_PORT=$val ;;
            SSH_HOST) SSH_HOST=$val ;; SSH_USER) SSH_USER=$val ;;
            SSH_PORT) SSH_PORT=$val ;; TMUX_SESSION) TMUX_SESSION=$val ;;
            *) die 'Unknown key in user.conf.' ;;
        esac
    done
    IFS=$saved_ifs
    [ "$restore_glob" = no ] || set +f
    unset config_lines
    [ -n "$KRB5_REALM" ] && [ -n "$KRB5_PRINCIPAL" ] && [ -n "$SSH_HOST" ] && [ -n "$SSH_USER" ] || die 'Incomplete user.conf.'
    case "$KRB5_PRINCIPAL:$KRB5_REALM" in -*|*:-*) die 'Principal and realm must not begin with a dash.' ;; esac
    case "$KRB5_PRINCIPAL" in *@"$KRB5_REALM") ;; *) die 'Principal realm does not match KRB5_REALM.' ;; esac
    case "$SSH_HOST:$SSH_USER:$KDC_HOST" in -*|*:-*) die 'Hosts and user must not begin with a dash.' ;; esac
    case "$TMUX_SESSION" in ''|-*|*[!a-zA-Z0-9_-]*) die 'TMUX_SESSION must use letters, digits, underscore or dash, and not start with dash.' ;; esac
    for port in "$SSH_PORT" "$KDC_PORT"; do
        case "$port" in ''|*[!0-9]*) die 'Ports must be numeric.' ;; esac
        [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || die 'Port outside 1..65535.'
    done
    case "$KRB5CCNAME" in FILE:/*) CC_FILE=${KRB5CCNAME#FILE:} ;; *) die 'Use an absolute FILE: credential cache for iSH.' ;; esac
    [ ! -L "$CC_FILE" ] || die 'Refusing a symlink credential cache.'
    mkdir -p "$CACHE_DIR"
    chmod 700 "$CACHE_DIR"
}
tgt_valid() {
    klist -s >/dev/null 2>&1 || return 1
    ticket_listing=$(klist 2>/dev/null) || return 1
    ticket_principal=$(printf '%s\n' "$ticket_listing" | sed -n 's/^Default principal: //p')
    [ "$ticket_principal" = "$KRB5_PRINCIPAL" ] || return 2
    printf '%s\n' "$ticket_listing" | grep -F "krbtgt/$KRB5_REALM@$KRB5_REALM" >/dev/null || return 1
}
ssh_gssapi() {
    # -F and ControlPath prevent local config/multiplexing from bypassing auth.
    ssh -F /dev/null -o GSSAPIAuthentication=yes -o GSSAPIDelegateCredentials=no \
        -o PreferredAuthentications=gssapi-with-mic -o PubkeyAuthentication=no \
        -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no \
        -o HostbasedAuthentication=no -o ControlMaster=no -o ControlPath=none \
        -o CanonicalizeHostname=no -o UpdateHostKeys=no \
        -o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
        -o "StrictHostKeyChecking=${HOST_KEY_POLICY:-yes}" \
        -p "$SSH_PORT" -l "$SSH_USER" "$@" "$SSH_HOST" "$REMOTE_COMMAND"
}
