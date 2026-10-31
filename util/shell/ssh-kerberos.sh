#!/bin/sh
# Shared POSIX helpers. Never source user configuration as shell code.
# The connection entrypoint supplies these variables before calling helpers.
# shellcheck disable=SC2154
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
    ticket_principal=$(printf '%s\n' "$ticket_listing" | sed -n 's/^.*[Pp]rincipal:[[:space:]]*//p' | head -1)
    [ "$ticket_principal" = "$KRB5_PRINCIPAL" ] || return 2
    printf '%s\n' "$ticket_listing" | grep -F "krbtgt/$KRB5_REALM@$KRB5_REALM" >/dev/null || return 1
}
ssh_gssapi_command() {
    # First values win in OpenSSH; caller options cannot weaken this policy.
    ssh -o GSSAPIAuthentication=yes -o GSSAPIDelegateCredentials=no \
        -o PreferredAuthentications=gssapi-with-mic -o PubkeyAuthentication=no \
        -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no \
        -o HostbasedAuthentication=no -o ControlMaster=no -o ControlPath=none \
        -o CanonicalizeHostname=no -o UpdateHostKeys=no \
        -o ConnectTimeout=10 -o "ServerAliveInterval=${ssh_alive_interval:-30}" -o ServerAliveCountMax=3 \
        -o "StrictHostKeyChecking=${HOST_KEY_POLICY:-yes}" \
        "$@"
}

# Used by the iSH diagnostic command with its existing per-device profile.
ssh_gssapi() {
    ssh_gssapi_command -F /dev/null -p "$SSH_PORT" -l "$SSH_USER" "$@" "$SSH_HOST" "$REMOTE_COMMAND"
}

require_tgt() {
    export LC_ALL=C
    for cmd in kinit klist ssh; do
        command -v "$cmd" >/dev/null 2>&1 || die "Missing $cmd; run ./init core."
    done
    if tgt_valid; then return; fi
    if [ "$check_only" = 1 ] || [ ! -t 0 ]; then
        die 'TGT missing, expired, invalid or principal mismatch; run ssh-connect interactively to obtain the configured ticket.'
    fi
    # Reuse the device's configured keytab/keychain repair before prompting.
    if command -v kinit-auto-login >/dev/null 2>&1; then
        printf '%s\n' 'Refreshing Kerberos credentials...' >&2
        if kinit-auto-login renew --principal "$KRB5_PRINCIPAL" && tgt_valid; then return; fi
    fi
    # Never renew another identity's cache on behalf of this host.
    cached_principal=$(klist 2>/dev/null | sed -n 's/^.*[Pp]rincipal:[[:space:]]*//p' | head -1)
    if [ "$cached_principal" = "$KRB5_PRINCIPAL" ]; then
        if kinit -R && tgt_valid; then return; fi
    fi
    printf '%s\n' 'A matching TGT is required. kinit will prompt directly; no password is saved.' >&2
    kinit "$KRB5_PRINCIPAL" || die 'kinit failed; check realm, KDC, clock and VPN.'
    tgt_valid || die 'kinit did not produce the expected TGT; refusing SSH.'
}

# Optional per-alias mapping, shared by Termux, iSH and desktop SSH clients.
# Format: HOST PRINCIPAL [TMUX_SESSION]. This file is data, never shell code.
load_ssh_kerberos() {
    kerberos_enabled=0
    ish_connection=0
    kerberos_file=${SSH_CONNECT_KERBEROS_FILE:-$xdg_config_home/ssh/kerberos}
    if [ -f "$kerberos_file" ]; then
        mapping=$(awk -v target="$host" '
            { sub(/[[:space:]]*#.*/, "") }
            NF && ($1 ~ /^-/ || $1 ~ /[^A-Za-z0-9_.:-]/ ||
                   NF < 2 || NF > 3 || $2 !~ /^[A-Za-z0-9_][A-Za-z0-9_.\/+\-]*@[A-Za-z0-9_.-]+$/ ||
                   (NF == 3 && $3 !~ /^[A-Za-z0-9_][A-Za-z0-9_-]*$/)) { invalid=1 }
            $1 == target { if (found++) invalid=1; print $2, (NF == 3 ? $3 : "dev") }
            END { exit invalid ? 1 : 0 }
        ' "$kerberos_file") || die 'Invalid SSH Kerberos mapping; use HOST PRINCIPAL [TMUX_SESSION], one entry per host.'
        if [ -n "$mapping" ]; then
            KRB5_PRINCIPAL=${mapping%% *}
            KRB5_REALM=${KRB5_PRINCIPAL##*@}
            TMUX_SESSION=${mapping#* }
            kerberos_enabled=1
        fi
    fi
    # Keep existing iSH installations working without rewriting their profile.
    # Only the exact configured hostname opts into that profile.
    ish_profile=${ISH_CONFIG_DIR:-$xdg_config_home/ish-kerberos}/user.conf
    if [ "$kerberos_enabled" = 0 ] && [ -f "$ish_profile" ] &&
       [ "$(awk -F= '$1 == "SSH_HOST" {print $2}' "$ish_profile")" = "$host" ]; then
        load_config
        kerberos_enabled=1
        ish_connection=1
    fi
    # SSH config is also an opt-in: a separate alias mapping is optional.
    if [ "$kerberos_enabled" = 0 ]; then
        effective=$(ssh -G "$@" "$host") || die 'Cannot inspect SSH settings.'
        if printf '%s\n' "$effective" | grep -Fxq 'gssapiauthentication yes'; then
            KRB5_PRINCIPAL=$(awk -F= '$1 == "KRB_PRINCIPAL" {print $2; exit}' \
                "$xdg_config_home/kinit-auto-login/kinit.env" 2>/dev/null || true)
            case "$KRB5_PRINCIPAL" in ''|your.name@*)
                KRB5_PRINCIPAL=$(klist 2>/dev/null | sed -n 's/^.*[Pp]rincipal:[[:space:]]*//p' | head -1) ;;
            esac
            case "$KRB5_PRINCIPAL" in
                ''|-*|*[!a-zA-Z0-9_@./:+-]*|*@*@*)
                    die 'Cannot determine Kerberos principal; configure HOST PRINCIPAL in ~/.config/ssh/kerberos.' ;;
                *@?*) ;; *) die 'Kerberos principal must include a realm; configure ~/.config/ssh/kerberos.' ;;
            esac
            KRB5_REALM=${KRB5_PRINCIPAL##*@}
            TMUX_SESSION=dev
            kerberos_enabled=1
        fi
    fi
}

check_workbench_policy() {
    # Workbench launches its own ssh processes and has no SSH-options API.
    # Require safe persistent host settings before handing off to it.
    [ "$ish_connection" = 0 ] || die 'Use --tmux for the iSH profile; --workbench requires a standard SSH alias and shared Kerberos mapping.'
    effective=$(ssh -G "$host") || die 'Cannot inspect workbench SSH settings.'
    for required in 'gssapiauthentication yes' 'gssapidelegatecredentials no' \
        'preferredauthentications gssapi-with-mic' 'passwordauthentication no' \
        'kbdinteractiveauthentication no' 'hostbasedauthentication no'; do
        printf '%s\n' "$effective" | grep -Fxq "$required" ||
            die 'Unsafe workbench SSH settings; add the Kerberos Host block documented in docs/platforms/termux.md, or use --tmux.'
    done
    printf '%s\n' "$effective" | grep -Eq '^pubkeyauthentication (no|false)$' || die 'Disable PubkeyAuthentication for this workbench host.'
    printf '%s\n' "$effective" | grep -Eq '^controlmaster (no|false)$' || die 'Disable ControlMaster for this workbench host.'
    if printf '%s\n' "$effective" | grep '^controlpath ' | grep -vq '^controlpath none$'; then
        die 'Set ControlPath none for this workbench host.'
    fi
    printf '%s\n' "$effective" | grep -Eq '^stricthostkeychecking (yes|true|ask)$' || die 'Require trusted host keys for this workbench host.'
}
