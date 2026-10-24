"""iSH's Alpine client, using the same task runner and shared dotfiles as Termux."""
from pathlib import Path
import os
import re
import shlex

from .engine import Failure
from .tasks import sequence, task

# Native clients only. Codex and development toolchains run on the SSH host.
ISH_PACKAGES = ('ca-certificates bash curl fd file fzf git jq krb5 '
                'less nano openssh-client-krb5 python3 rsync shadow '
                'tig tmux tree unzip vim which zip zoxide zsh').split()


@task()
def install_ish_core_packages(c):
    if not c.dry_run:
        if os.geteuid() != 0:
            raise Failure('Run initialization as root inside iSH; no host sudo is needed')
        version = Path('/etc/alpine-release').read_text().strip()
        branch = '.'.join(version.split('.')[:2])
        if c.command('apk', '--print-arch', capture=True).strip() != 'x86':
            raise Failure('iSH requires a fresh Alpine x86 (32-bit) filesystem')
        repo_file = Path('/etc/apk/repositories')
        repo_text = repo_file.read_text()
        repos = repo_text.splitlines()
        repos = [r.strip() for r in repos if r.strip() and not r.lstrip().startswith('#')]
        if not repos or any(re.search(r'/(edge|v\d+\.\d+)(?:/|$)', r) and
                            f'/v{branch}/' not in r + '/' for r in repos):
            raise Failure('Empty or mixed Alpine repositories; import a fresh rootfs instead of a cross-version upgrade')
        if not any('/community' in r for r in repos):
            main = next((r.rstrip('/') for r in repos if r.rstrip('/').endswith(f'/v{branch}/main')), None)
            if main is None:
                raise Failure(f'Enable a matching v{branch}/community repository for the shared CLI tools')
            c.backup(repo_file)
            c.write(repo_file, repo_text.rstrip() + '\n' + main[:-4] + 'community\n', mode=0o644)
            c.note(f'Enabled same-version v{branch}/community; existing repositories were backed up')
        if branch == '3.18':
            c.note('Alpine 3.18 is a historical test baseline, not a maintained daily system')
    c.command('apk', 'update')
    c.command('apk', 'add', '--no-progress', *ISH_PACKAGES)
    c.command('apk', 'info', '-e', 'openssh-client-krb5')
    c.command('ssh', '-G', '-F', '/dev/null', '-o', 'GSSAPIAuthentication=yes', 'localhost', capture=True)


def append_block(c, path, block):
    """Preserve local startup content and make repeat/sync runs idempotent."""
    content = path.read_text() if path.exists() else ''
    begin, end = '# -- dotfiles iSH begin --', '# -- dotfiles iSH end --'
    pattern = re.compile(r'^' + re.escape(begin) + r'\n.*?^' + re.escape(end) + r'(?:\n|$)', re.M | re.S)
    updated = pattern.sub('', content).rstrip('\n')
    updated = (updated + '\n\n' if updated else '') + begin + '\n' + block + end + '\n'
    if updated != content or path.is_symlink():
        c.backup(path)
        c.write(path, updated)


@task()
def ish_client_setup(c):
    conf = c.config / 'ish-kerberos'
    c.mkdir(conf)
    c.mkdir(c.cache / 'ish-kerberos')
    if not c.dry_run:
        conf.chmod(0o700)
        (c.cache / 'ish-kerberos').chmod(0o700)
    for name in ('user.conf', 'krb5.conf'):
        dest = conf / name
        if not dest.exists() and not dest.is_symlink():
            # Keep an administrator-supplied system profile on first install.
            source = Path('/etc/krb5.conf') if name == 'krb5.conf' else None
            if source is None or not source.is_file():
                source = c.repo / 'config/ish' / (name + '.example')
            c.write(dest, source.read_text())
    for name in ('ish-doctor', 'fd'):
        c.link(c.repo / 'util/ish' / name, c.bin / name)
    for name in ('ssh-connect', 'ssh-setup', 'ssh-pair'):
        c.link(c.repo / 'util/shell' / name, c.bin / name)
    # Retire only our former link; never delete a user's same-named command.
    old = c.bin / 'ish-connect'
    if old.is_symlink() and old.resolve() == (c.repo / 'util/ish/ish-connect').resolve():
        c.record('unlink', path=str(old))
        if not c.dry_run:
            old.unlink()
    c.mkdir(c.home / '.ssh')
    if not c.dry_run:
        (c.home / '.ssh').chmod(0o700)
    # First values win: explicit local host settings stay ahead of defaults.
    c.task('ssh_setup')


@task()
def ish_basic_setup(c):
    sequence(c, 'xdg_dir_create', 'zsh_config_setup', 'tmux_config_setup',
             'vim_config_setup', 'tig_setup', 'python_setup')
    c.task('git_setup', 'configure-only')
    for name in ('theme-sync', 'tmux-appearance-fallback'):
        c.link(c.repo / 'util/shell' / name, c.bin / name)
    # This also makes manual kinit/klist/ssh and the helpers use the same cache.
    block = ('export DOTFILES_HOME=' + shlex.quote(str(c.repo)) + '\n'
             '. "$DOTFILES_HOME/config/ish/env.sh"\n')
    for name in ('.profile', '.zshenv'):
        append_block(c, c.home / name, block)
    c.task('ish_client_setup')
    c.note('Open a new shell (or source ~/.profile). Configure with ./init kerberos; connect with ssh-connect --tmux.')


@task()
def prepare_ish_env(c, mode='core'):
    if mode not in ('core', 'all'):
        raise Failure('iSH supports core and all; use basic/sync for configuration only')
    if mode == 'all':
        c.note('iSH has no extra desktop package set; all uses core, as on Termux')
    sequence(c, 'install_ish_core_packages', 'zinit_install', 'ish_basic_setup',
             'set_default_shell', 'tmux_plugins_setup', 'vim_plugins_setup')
    c.note('SKIP ripgrep/starship: they hit unsupported instructions in the tested Alpine build; use grep/find and the native zsh prompt. fd uses a single-worker compatibility wrapper.')
    c.note('iSH client ready. Android services, local sshd/agents and local Codex are not part of this client profile.')


@task()
def ish_kerberos(c):
    c.task('ish_client_setup')
    conf = c.config / 'ish-kerberos'
    # Prompts are visible through Context.prompt, never passwords or ticket data.
    realm = c.prompt('Kerberos realm', 'EXAMPLE.COM' if c.dry_run else '')
    principal = c.prompt('Kerberos principal', 'yourname@' + realm)
    kdc = c.prompt('KDC hostname (or dns for DNS SRV discovery)', 'dns')
    host = c.prompt('SSH hostname', 'dev.example.com' if c.dry_run else '')
    user = c.prompt('SSH username', principal.split('@')[0])
    port = c.prompt('SSH port', '22')
    session = c.prompt('Remote tmux session', 'dev')
    for value in (realm, principal, kdc, host, user, session):
        if not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_@./:+-]*', value):
            raise Failure('Use literal realm, principal, hostname and username values; no shell expressions')
    if not principal.endswith('@' + realm):
        raise Failure('Principal must end with @REALM')
    if not port.isdecimal() or not 1 <= int(port) <= 65535:
        raise Failure('SSH port must be in 1..65535')
    if not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_-]*', session):
        raise Failure('tmux session may contain only letters, digits, underscore and dash')
    if c.prompt('Replace user.conf and krb5.conf? Existing files will be backed up', 'no').lower() not in ('yes', 'y'):
        c.note('Kept existing Kerberos configuration. You can edit it directly instead.')
        return
    profile = ('[libdefaults]\n default_realm = ' + realm + '\n rdns = false\n'
               ' dns_canonicalize_hostname = false\n forwardable = false\n'
               ' dns_lookup_realm = false\n udp_preference_limit = 1\n'
               ' dns_lookup_kdc = ' + ('true' if kdc == 'dns' else 'false') + '\n')
    if kdc != 'dns':
        profile += f'[realms]\n {realm} = {{\n  kdc = {kdc}:88\n }}\n'
    values = f'KRB5_REALM={realm}\nKRB5_PRINCIPAL={principal}\n'
    if kdc != 'dns':
        values += f'KDC_HOST={kdc}\n'
    values += f'SSH_HOST={host}\nSSH_USER={user}\nSSH_PORT={port}\nTMUX_SESSION={session}\n'
    for name, text in (('user.conf', values), ('krb5.conf', profile)):
        c.backup(conf / name)
        c.write(conf / name, text)
    c.note('Configured. In a new shell: ssh-connect --tmux will request kinit when needed. No password was requested or saved.')
