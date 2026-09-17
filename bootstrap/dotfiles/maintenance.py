"""Independent configuration and checkout maintenance tasks."""
import os
from pathlib import Path
import re
import shutil
import time

from .engine import Failure
from .tasks import task


@task('kerberos')
def kerberos(c):
    domain = c.prompt('Kerberos DNS domain', 'corp.example' if c.dry_run else '')
    realm = c.prompt('Kerberos realm', domain.upper())
    kdcs = c.prompt('KDC hosts', ' '.join('krb5auth' + n + '.' + domain for n in ('1', '2', '3', ''))).split()
    admin = c.prompt('Kerberos admin server', 'krb5auth.' + domain)
    for value, pattern in [(domain, r'[A-Za-z0-9._-]+'), (realm, r'[A-Z0-9._-]+'),
                           *[(v, r'[A-Za-z0-9._:-]+') for v in [*kdcs, admin]]]:
        if not re.fullmatch(pattern, value):
            raise Failure('Invalid Kerberos domain, realm, or hostname')
    prefix = c.env.get('PREFIX', '/data/data/com.termux/files/usr')
    target = Path(prefix) / 'etc/krb5.conf' if c.platform == 'termux' else Path('/etc/krb5.conf')
    content = f'''[libdefaults]
  default_realm = {realm}
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
  {realm} = {{
'''
    content += ''.join('    kdc = ' + host + '\n' for host in kdcs)
    content += f'''    master_kdc = {admin}
    admin_server = {admin}
    default_domain = {domain}
  }}

[domain_realm]
  .{domain} = {realm}
  {domain} = {realm}

[login]
  krb4_convert = true
  krb4_get_tickets = false
'''
    backup = Path(str(target) + '.pre-bootstrap')
    if target.exists() and not backup.exists():
        if c.platform == 'termux':
            c.copy(target, backup)
        else:
            c.command('sudo', 'install', '-m', '600', target, backup)
    c.write(target, content, privileged=c.platform != 'termux')
    c.note(f'Kerberos configured. Test with kinit USER@{realm} and klist.')


@task('migrate_xdg')
def migrate_xdg(c):
    target = c.config / 'dotfiles'
    legacy = c.home / '.dotfiles'
    old_physical = legacy.resolve() if legacy.exists() else None
    if not c.config.is_absolute():
        raise Failure('XDG_CONFIG_HOME must be absolute')
    already = target.exists() and target.resolve() == c.repo
    if already:
        if legacy.exists() and (not legacy.is_symlink() or legacy.resolve() != target.resolve()):
            raise Failure('Refusing to replace an unrelated legacy path')
    else:
        if target.exists() or target.is_symlink():
            raise Failure('Refusing to overwrite migration target: ' + str(target))
        if legacy.is_symlink() or not legacy.exists() or c.repo != legacy.resolve():
            raise Failure('Migration must start from the legacy ~/.dotfiles checkout')
        c.record('move-checkout', source=str(c.repo), target=str(target))
        if not c.dry_run:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(c.repo), target)
            try:
                legacy.symlink_to(target, target_is_directory=True)
            except OSError:
                shutil.move(str(target), c.repo)
                raise
    roots = [c.config, c.bin, *[c.home / p for p in ('.codex', '.claude', '.ssh', 'Library/LaunchAgents', 'Library/Rime')]]
    candidates = [p for p in c.home.iterdir() if p.is_symlink() and p != legacy]
    for root in roots:
        if root.is_symlink():
            candidates.append(root)
        elif root.exists():
            for base, dirs, files in os.walk(root, followlinks=False):
                candidates += [Path(base) / n for n in [*dirs, *files] if (Path(base) / n).is_symlink()]
    for path in dict.fromkeys(candidates):
        # Windows readlink may return an extended-length \\?\ path. Compare
        # lexical absolute paths before following the temporary compatibility link.
        value = str(path.readlink()).removeprefix('\\\\?\\')
        if not os.path.isabs(value):
            value = os.path.abspath(path.parent / value)
        value = os.path.normcase(os.path.normpath(value))
        suffix = None
        for prefix in (str(legacy), str(old_physical) if old_physical else ''):
            if prefix:
                prefix = os.path.normcase(os.path.normpath(prefix.removeprefix('\\\\?\\')))
            if prefix and (value == prefix or value.startswith(prefix + os.sep)):
                suffix = value[len(prefix):].lstrip('/\\')
                break
        if suffix is None and '/.dotfiles/' in value:
            suffix = value.split('/.dotfiles/', 1)[1]
        if suffix is None:
            continue
        dest = target / suffix
        c.record('retarget-link', path=str(path), target=str(dest))
        if not c.dry_run:
            tmp = path.with_name(path.name + f'.migrate-{time.time_ns()}')
            tmp.symlink_to(dest, target_is_directory=dest.is_dir())
            os.replace(tmp, path)
    if c.platform == 'macos' and (c.home / 'Library/Application Support/Alfred/prefs.json').exists():
        c.command(target / 'util/macos/alfred-prefs-folder', env={'DOTFILES_HOME': str(target)})
    # Compatibility link stays in place if any preceding operation fails.
    if legacy.is_symlink():
        c.record('unlink', path=str(legacy))
        if not c.dry_run:
            legacy.unlink()


# Named composition helpers remain usable without shell eval.
@task('tmux_setup')
def tmux_setup(c):
    c.task('tmux_config_setup')
    c.task('tmux_plugins_setup')


@task('vim_setup')
def vim_setup(c):
    c.task('vim_config_setup')
    c.task('vim_plugins_setup')
