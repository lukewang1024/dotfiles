#!/bin/sh
# Interactively configure a Kerberos realm without organization-specific data.

set -eu

die()
{
  printf '%s\n' "kerberos-setup: $*" >&2
  exit 1
}

if [ "${1:-}" = -h ] || [ "${1:-}" = --help ]; then
  cat <<'EOF'
Usage: ./init kerberos

Interactively configures krb5.conf. Realm, DNS domain, KDCs, and admin server
are supplied at runtime and are never hardcoded in this script.
EOF
  exit 0
fi
[ "$#" -eq 0 ] || die 'this task is interactive and accepts no arguments'

printf '%s' 'Kerberos DNS domain (for example, corp.example): '
IFS= read -r domain || die 'could not read Kerberos domain'
[ -n "$domain" ] || die 'Kerberos domain may not be empty'

realm_default=$(printf '%s' "$domain" | tr '[:lower:]' '[:upper:]')
printf 'Kerberos realm [%s]: ' "$realm_default"
IFS= read -r realm || die 'could not read Kerberos realm'
realm=${realm:-$realm_default}

kdc_default="krb5auth1.$domain krb5auth2.$domain krb5auth3.$domain krb5auth.$domain"
printf 'KDC hosts [%s]: ' "$kdc_default"
IFS= read -r kdc_list || die 'could not read KDC hosts'
kdc_list=${kdc_list:-$kdc_default}

admin_default="krb5auth.$domain"
printf 'Kerberos admin server [%s]: ' "$admin_default"
IFS= read -r admin_server || die 'could not read admin server'
admin_server=${admin_server:-$admin_default}

case "$realm" in *[!A-Z0-9._-]*|'') die 'realm contains unsafe characters' ;; esac
case "$domain" in *[!A-Za-z0-9._-]*|'') die 'domain contains unsafe characters' ;; esac
for host in $kdc_list $admin_server; do
  case "$host" in *[!A-Za-z0-9._:-]*) die "host contains unsafe characters: $host" ;; esac
done

if [ -n "${TERMUX_VERSION:-}" ] || [ "${PREFIX:-}" = '/data/data/com.termux/files/usr' ]; then
  krb5_conf=${PREFIX:?Termux PREFIX is not set}/etc/krb5.conf
  install_file()
  {
    install -m 600 "$1" "$2"
  }
else
  krb5_conf=/etc/krb5.conf
  install_file()
  {
    sudo install -m 600 "$1" "$2"
  }
fi

tmp_dir=${TMPDIR:-/tmp}
tmp_conf=$tmp_dir/krb5.conf.$$
trap 'rm -f "$tmp_conf"' EXIT HUP INT TERM
{
  cat <<EOF
[libdefaults]
  default_realm = $realm
  dns_canonicalize_hostname = false
  dns_lookup_realm = false
  dns_lookup_kdc = false
  kdc_timesync = 1
  ccache_type = 4
  forwardable = true
  proxiable = true
  rdns = false
  ignore_acceptor_hostname = true

[realms]
  $realm = {
EOF
  for host in $kdc_list; do
    printf '    kdc = %s\n' "$host"
  done
  cat <<EOF
    master_kdc = $admin_server
    admin_server = $admin_server
    default_domain = $domain
  }

[domain_realm]
  .$domain = $realm
  $domain = $realm

[login]
  krb4_convert = true
  krb4_get_tickets = false
EOF
} >"$tmp_conf"

if [ -f "$krb5_conf" ] && [ ! -f "$krb5_conf.pre-bootstrap" ]; then
  install_file "$krb5_conf" "$krb5_conf.pre-bootstrap"
fi
install_file "$tmp_conf" "$krb5_conf"

printf 'Kerberos configuration written to %s\n' "$krb5_conf"
printf 'Test it with: kinit USER@%s && klist\n' "$realm"
