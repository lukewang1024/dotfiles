"""Platform task definitions. All effects go through Context, including dry runs."""
from __future__ import annotations

import json
from pathlib import Path
import platform
import re
import shutil

from .engine import Failure, Skip

DATA = Path(__file__).parent
PACKAGES = json.loads((DATA / 'packages.json').read_text(encoding='utf-8'))
LINKS = json.loads((DATA / 'links.json').read_text(encoding='utf-8'))
TASKS = {}


def task(name=None):
    def decorate(fn):
        TASKS[name or fn.__name__] = fn
        return fn
    return decorate


def sequence(c, *names):
    for name in names:
        c.task(name)


def links(c, group):
    for source, target in LINKS.get(group, []):
        if source == '$unit':
            # systemd's directory entries are expanded by the platform task.
            continue
        if source == '$config_dir/ssh/config' and target in ('~/.ssh/config', '$HOME/.ssh/config'):
            # The legacy inventory lists a symlink; SSH now has a local entrypoint.
            c.task('ssh_setup')
            continue
        target = target.replace('~/.config/', '$XDG_CONFIG_HOME/').replace('$HOME/.config/', '$XDG_CONFIG_HOME/')
        c.link(source, target, allow_missing=not c.path(source).is_relative_to(c.repo))


def packages(group, variable='pkgs', index=0):
    return PACKAGES[group][variable][index]


def install(c, manager, values, *flags):
    if not values:
        return
    if manager == 'apt':
        c.command('sudo', 'apt', 'update')
        c.command('sudo', 'apt', 'upgrade', '-y')
        available = []
        for value in values:
            candidate = c.command('apt-cache', 'policy', value, capture=True)
            if c.dry_run or re.search(r'Candidate:\s*(?!\(none\))\S+', candidate):
                available.append(value)
            else:
                c.note(f'No APT candidate: {value}')
        if available:
            c.command('sudo', 'apt', 'install', '-y', *flags, *available)
    elif manager == 'pacman':
        c.command('sudo', 'pacman', '-Sy', '--needed', '--noconfirm', *flags, *values)
    elif manager == 'aur':
        c.command('yay', '-Sy', '--needed', *flags, *['aur/' + p for p in values])
    elif manager == 'winget':
        for value in values:
            c.command('winget', 'install', '--id', value, '--exact', '--accept-package-agreements', '--accept-source-agreements', *flags)
    elif manager == 'scoop-fonts':
        c.command('sudo', 'scoop', 'install', *values)
    else:
        # Cask package installers may invoke sudo themselves and need a terminal.
        c.command(manager, 'install', *flags, *values,
                  interactive=manager == 'brew' and '--cask' in flags)


@task('basic_env_setup')
def basic(c):
    sequence(c, 'xdg_dir_create', 'profile_setup', 'zsh_config_setup', 'ssh_setup', 'tmux_config_setup')
    c.task('git_setup', 'configure-only')
    sequence(c, 'tig_setup', 'npm_setup', 'pnpm_config_setup', 'python_setup', 'vim_config_setup')
    c.task('util_setup', 'configure-only')


@task('sync_setup')
def sync(c):
    c.task('set_windows_links' if c.platform == 'windows' else 'basic_env_setup')
    if c.platform == 'termux':
        c.task('termux_shell_setup')


@task('core_env_setup')
def core(c):
    sequence(c, 'basic_env_setup', 'shell_setup', 'tmux_plugins_setup', 'vim_plugins_setup',
             'anyenv_setup', 'rustup_setup', 'uv_setup', 'pnpm_setup')


@task('extra_env_setup')
def extra(c):
    sequence(c, 'util_setup', 'install_common_packages')


@task('env_setup')
def environment(c):
    sequence(c, 'core_env_setup', 'extra_env_setup')


@task()
def xdg_dir_create(c):
    for root, names in [(c.data, ('android', 'npm', 'terminfo')), (c.config, ('npm', 'wakatime')),
                        (c.state, ('bash', 'less', 'npm/logs', 'zsh')), (c.cache, ('npm', 'tldr', 'zsh'))]:
        for name in names:
            c.mkdir(root / name)


@task()
def profile_setup(c):
    raise Skip('.profile is intentionally not linked')


def register_links(name, group):
    @task(name)
    def action(c):
        links(c, group)


for _name, _group in [('tig_setup', 'shell/tig_setup'), ('vim_config_setup', 'shell/vim_config_setup'),
                      ('pnpm_config_setup', 'env/pnpm_config_setup'), ('apply_nix_app_configs', 'nix/apply_nix_app_configs')]:
    register_links(_name, _group)


@task()
def git_setup(c, mode='interactive'):
    dest = c.config / 'git/config'
    identities = ''
    if dest.exists() and not c.dry_run:
        identities = c.command('git', 'config', '--global', '--list', capture=True)
    c.backup(dest)
    if c.platform == 'termux':
        for name in ('alias', 'common'):
            c.link(c.repo / 'config/git' / name, c.config / 'git' / name)
        c.copy(c.repo / 'config/git/termux', dest)
    else:
        text = ''.join((c.repo / 'config/git' / name).read_text(encoding='utf-8') for name in ('alias', 'common'))
        local = c.repo / 'config/git/local'
        if local.exists():
            text += local.read_text(encoding='utf-8')
        c.write(dest, text)
    for name in ('git-branch-cleanup', 'git-clone-bare', 'git-new-branch', 'git-set-identity'):
        c.link(c.repo / 'util/shell' / name, c.bin / name)
    if c.platform == 'macos':
        c.command('git', 'config', '--global', 'credential.helper', 'osxkeychain')
    if c.platform == 'cygwin' or 'microsoft' in platform.release().lower():
        c.command('git', 'config', '--global', 'core.autocrlf', 'input')
        c.command('git', 'config', '--global', 'core.fileMode', 'false')
    saved = [line.split('=', 1) for line in identities.splitlines() if re.match(r'^user\.\w+\.\w+=', line)]
    if mode == 'configure-only':
        if c.platform != 'termux':
            for key, value in saved:
                c.command('git', 'config', '--global', key, value)
        return
    if saved and c.prompt('Reapply existing Git identities?', 'yes').lower() in ('y', 'yes'):
        for key, value in saved:
            c.command('git', 'config', '--global', key, value)
    if c.dry_run:
        c.record('prompt', label='Additional Git identities')
        return
    while True:
        identity = c.prompt('Add a Git identity (blank to finish)')
        if not identity:
            break
        if not re.fullmatch(r'[\w-]+', identity):
            raise Failure('Invalid Git identity name')
        for field in ('name', 'email', 'signingKey'):
            value = c.prompt('Git ' + field)
            if not value and field != 'signingKey':
                raise Failure(f'Git {field} may not be empty')
            if value:
                c.command('git', 'config', '--global', f'user.{identity}.{field}', value)


@task()
def npm_setup(c):
    target = c.config / 'npm/npmrc'
    c.backup(target)
    content = (c.repo / 'config/npm/common').read_text(encoding='utf-8')
    local = c.repo / 'config/npm/local'
    if local.exists():
        content += local.read_text(encoding='utf-8')
    c.write(target, content)


@task()
def python_setup(c):
    c.link(c.repo / 'config/python', c.config / 'python')
    if not (c.state / 'python_history').exists():
        c.write(c.state / 'python_history', '')


@task()
def ssh_setup(c):
    dest = c.home / '.ssh/config'
    shared = c.repo / 'config/ssh/config'
    begin = '# -- dotfiles SSH config begin --'
    end = '# -- dotfiles SSH config end --'
    def quoted(path):
        return '"' + path.as_posix().replace('"', '\\"') + '"'
    block = '\n'.join((begin, '# Local overrides precede shared defaults (SSH uses the first value).',
                       'Host *', '  Include ' + quoted(c.home / '.ssh/config.local'),
                       'Host *', '  Include ' + quoted(shared), 'Host *', end)) + '\n'
    content = dest.read_text(encoding='utf-8') if dest.exists() else ''
    if dest.is_symlink() and dest.resolve() == shared.resolve():
        # Replace the legacy link itself, never write through it into the repo.
        content = ''
    pattern = re.compile(r'^' + re.escape(begin) + r'\n.*?^' + re.escape(end) + r'(?:\n|$)', re.M | re.S)
    if pattern.search(content):
        updated = pattern.sub(lambda _: block, content)
    else:
        updated = content + ('\n' if content and not content.endswith('\n') else '')
        updated += ('\n' if content else '') + block
    if dest.is_symlink() or updated != content or not dest.exists():
        c.backup(dest)
        c.write(dest, updated)
    local = c.home / '.ssh/config.local'
    if not local.exists():
        c.write(local, '')
    elif not c.dry_run:
        local.chmod(0o600)


@task()
def tmux_config_setup(c):
    links(c, 'shell/tmux_config_setup')
    legacy = c.home / '.tmux.conf'
    if legacy.is_symlink() and str(legacy.readlink()).endswith('/.dotfiles/config/tmux/tmux.conf'):
        c.record('unlink', path=str(legacy))
        if not c.dry_run:
            legacy.unlink()
    dest = c.config / 'sesh'
    if dest.is_symlink():
        c.backup(dest)
    content = (c.repo / 'config/sesh/sesh.toml.in').read_text(encoding='utf-8').replace('@DOTFILES_DIR@', str(c.repo)).replace('@XDG_CONFIG_HOME@', str(c.config))
    c.write(dest / 'sesh.toml', content)
    metrics = c.bin / 'tmux-host-metrics'
    if metrics.is_symlink() and metrics.readlink() == c.repo / 'util/shell/tmux-host-metrics':
        c.record('unlink', path=str(metrics))
        if not c.dry_run:
            metrics.unlink()


@task()
def tmux_plugins_setup(c):
    if not c.dry_run and (not c.exists('tmux') or not c.exists('git')):
        raise Skip('tmux or git is not installed')
    root = c.data / 'tmux/plugins'
    tpm = root / 'tpm'
    if not tpm.exists():
        c.sync_repo(tpm, 'https://github.com/tmux-plugins/tpm')
    c.command(tpm / 'bin/install_plugins')
    wb = root / 'tmux-agent-workbench'
    if c.dry_run or (wb / 'install').exists():
        c.command('git', '-C', wb, 'pull', '--ff-only')
        c.command(wb / 'install', c.bin)


@task()
def vim_plugins_setup(c):
    plug = c.data / 'vim/autoload/plug.vim'
    if not plug.exists():
        c.download('https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim', plug)
    c.command('vim', '-es', '-u', c.config / 'vim/vimrc', '-c', 'PlugInstall --sync', '-c', 'qa!')


@task()
def zinit_install(c):
    c.sync_repo(c.data / 'zinit/zinit.git', 'https://github.com/zdharma-continuum/zinit.git')


@task()
def zsh_config_setup(c):
    for source, target in LINKS['shell/zsh_config_setup']:
        if source.endswith('/zinit.zshrc') and not (c.data / 'zinit/zinit.git').exists() and not c.dry_run:
            continue
        c.link(source, target)


@task()
def zsh_common_setup(c):
    choices = ['/etc/zshenv', '/etc/zsh/zshenv', '/usr/local/etc/zshenv']
    dest = next((Path(p) for p in choices if Path(p).exists()), Path('/etc/zshenv'))
    export = 'export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"'
    content = dest.read_text(encoding='utf-8') if dest.exists() else ''
    if 'ZDOTDIR=' not in content:
        c.write(dest, content + '\n' + export + '\n', mode=0o644, privileged=True)
    links(c, 'shell/zsh_common_setup')


@task()
def zinit_setup(c):
    c.task('zinit_install')
    c.link(c.repo / 'config/zsh/zinit.zshrc', c.config / 'zsh/.zshrc')
    c.task('zsh_common_setup')


@task()
def set_default_shell(c, name='zsh'):
    if c.platform == 'termux':
        c.command('chsh', '-s', name, interactive=True)
        return
    shell = shutil.which(name, path=c.env['PATH']) or name
    current = c.env.get('SHELL', '')
    if not c.dry_run:
        if c.exists('getent'):
            current = c.command('getent', 'passwd', c.env.get('USER', ''), capture=True).strip().split(':')[-1]
        elif c.platform == 'macos':
            current = c.command('dscl', '.', '-read', '/Users/' + c.env['USER'], 'UserShell', capture=True).split()[-1]
    if Path(current).name == name:
        raise Skip('Login shell is already ' + name)
    dest = Path('/etc/shells')
    content = dest.read_text(encoding='utf-8') if dest.exists() else ''
    if shell not in content.splitlines():
        c.write(dest, content + '\n' + shell + '\n', mode=0o644, privileged=True)
    c.command('chsh', '-s', shell, interactive=True)


@task()
def shell_setup(c):
    sequence(c, 'zinit_setup', 'set_default_shell')


@task()
def git_hooks_setup(c):
    hooks = c.repo / 'util/git/hooks'
    c.record('chmod', path=str(hooks / '*'), mode='executable')
    if not c.dry_run:
        for p in hooks.iterdir():
            if p.is_file():
                p.chmod(p.stat().st_mode | 0o111)
    if c.dry_run or (c.repo / '.git').exists():
        c.command('git', '-C', c.repo, 'config', '--local', 'core.hooksPath', hooks)


@task()
def util_setup(c, mode='all'):
    links(c, 'env/util_setup')
    if mode != 'configure-only':
        for name, args in [('claude-settings-apply', []), ('codex-settings-apply', []), ('agent-skills-install', []),
                           ('agent-skills-prune', ['--apply']), ('agent-hooks-prune', ['--apply']), ('open-computer-use-sync', [])]:
            rc = c.command(c.repo / 'util/agent' / name, *args, check=False)
            if rc:
                c.note(f'Optional agent setup needs attention: {name} (exit {rc})')
        if c.platform == 'macos':
            c.command(c.repo / 'util/shell/alacritty-appearance', 'auto', check=False)
    c.task('git_hooks_setup')


@task()
def anyenv_setup(c):
    manifest = Path(c.env.get('ANYENV_DEFINITION_ROOT', str(c.config / 'anyenv/anyenv-install')))
    if not manifest.is_dir():
        c.command('anyenv', 'install', '--force-init', 'https://github.com/lukewang1024/anyenv-install.git')
    for name in ('goenv', 'nodenv', 'pyenv', 'rbenv'):
        c.command('anyenv', 'install', '--skip-existing', name)
    # These paths are explicit; no eval of emitted shell initialization code.
    groups = {'nodenv': ['nodenv/node-build', 'nodenv/nodenv-default-packages', 'nodenv/nodenv-package-json-engine',
                         'nodenv/nodenv-package-rehash', 'nodenv/nodenv-update'],
              'pyenv': ['pyenv/pyenv-doctor', 'pyenv/pyenv-update', 'pyenv/pyenv-virtualenv', 'pyenv/pyenv-which-ext'],
              'rbenv': ['rbenv/ruby-build', 'rbenv/rbenv-vars', 'rbenv/rbenv-each', 'rbenv/rbenv-default-gems',
                        'rkh/rbenv-update', 'tpope/rbenv-communal-gems', 'mislav/rbenv-user-gems']}
    for tool, repos in groups.items():
        root = c.command(tool, 'root', capture=True).strip() if not c.dry_run else str(c.data / 'anyenv/envs' / tool)
        for repo in repos:
            c.sync_repo(Path(root) / 'plugins' / repo.split('/')[-1], 'https://github.com/' + repo)


@task()
def rustup_setup(c):
    if c.exists('rustup') and c.command('rustup', 'show', 'active-toolchain', check=False) == 0:
        raise Skip('Rust toolchain is already installed')
    c.installer('https://sh.rustup.rs', 'sh', '-y', '--no-modify-path')


@task()
def install_uv(c):
    if c.exists('uv'):
        raise Skip('uv is already installed')
    if c.platform == 'windows':
        c.installer('https://astral.sh/uv/install.ps1', 'powershell', env={'UV_INSTALL_DIR': str(c.bin), 'UV_NO_MODIFY_PATH': '1'})
    else:
        c.installer('https://astral.sh/uv/install.sh', 'sh', env={'UV_INSTALL_DIR': str(c.bin), 'UV_NO_MODIFY_PATH': '1'})
    c.refresh_path()
    if not c.dry_run and not c.exists('uv'):
        raise Failure('uv installer did not produce an executable')


TASKS['uv_setup'] = install_uv


@task()
def install_pnpm(c):
    if c.exists('pnpm'):
        raise Skip('pnpm is already installed')
    pnpm_home = c.data / 'pnpm'
    c.env['PNPM_HOME'] = str(pnpm_home)
    if c.exists('brew') and c.command('brew', 'install', 'pnpm', check=False) == 0:
        return
    extra = {'PNPM_HOME': str(pnpm_home)}
    if c.platform == 'macos' and platform.machine() == 'x86_64':
        extra['PNPM_VERSION'] = '10.25.0'
    if c.platform == 'windows':
        c.command('npm', 'install', '-g', 'pnpm')
    else:
        c.installer('https://get.pnpm.io/install.sh', 'sh', env=extra)


@task()
def pnpm_setup(c):
    sequence(c, 'install_pnpm', 'pnpm_config_setup')


def language_packages(c, name, level):
    if level not in ('core', 'all'):
        raise Failure('Package level must be core or all')
    values = list(packages('pkg/' + name, 'core_pkgs'))
    if level == 'all':
        values += PACKAGES['pkg/' + name].get('extra_pkgs', [[]])[0]
    return values


@task()
def install_cargo_packages(c, level='all'):
    c.command('cargo', 'install', *language_packages(c, 'install_cargo_packages', level))


@task()
def install_gem_packages(c, level='all'):
    c.command('gem', 'install', '--no-document', *language_packages(c, 'install_gem_packages', level))


@task()
def install_npm_cli_packages(c, level='all'):
    c.task('install_pnpm')
    c.command('pnpm', 'add', '-g', *language_packages(c, 'install_npm_cli_packages', level))


@task()
def install_npm_gui_packages(c, level='all'):
    c.task('install_pnpm')
    c.command('pnpm', 'add', '-g', *language_packages(c, 'install_npm_gui_packages', level))


@task()
def install_npm_packages(c, level='all'):
    c.task('install_npm_cli_packages', level)
    c.task('install_npm_gui_packages', level)


@task()
def install_pip_packages(c, level='all'):
    c.task('install_uv')
    for value in language_packages(c, 'install_pip_packages', level):
        c.command('uv', 'tool', 'install', '--upgrade', value)


@task()
def install_common_packages(c, level='all'):
    for name in ('install_cargo_packages', 'install_npm_packages', 'install_gem_packages', 'install_pip_packages'):
        c.task(name, level)
    if level == 'all':
        sequence(c, 'install_ai_agent_tools', 'install_other_packages')


@task()
def install_ai_agent_tools(c):
    c.installer('https://claude.ai/install.sh', 'bash')
    c.installer('https://chatgpt.com/codex/install.sh', 'sh', env={'CODEX_NON_INTERACTIVE': '1'})


@task()
def install_any_script(c, name, url):
    if Path(name).name != name:
        raise Failure('Script name must be a filename')
    target = c.download(url, c.bin / name)
    if not c.dry_run:
        target.chmod(0o755)


@task()
def install_other_packages(c):
    links(c, 'pkg/install_other_packages')
    c.task('install_any_script', 'hls-fetch', 'https://raw.githubusercontent.com/osklil/hls-fetch/master/hls-fetch')


@task()
def rime_setup(c):
    c.installer('https://git.io/rime-install', 'bash', 'jyutping', 'emoji')


@task()
def install_homebrew(c):
    if not c.exists('brew'):
        c.installer('https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh', 'bash', interactive=True)
        c.refresh_path()
    # command-not-found is built into Homebrew; its former tap is deprecated.


TASKS['install_linuxbrew'] = install_homebrew


for _name in ('install_nix_brew_runtimes', 'install_nix_brew_core_packages', 'install_nix_brew_extra_packages'):
    def _make(name):
        @task(name)
        def action(c):
            if name == 'install_nix_brew_core_packages':
                c.command('brew', 'tap', 'beeftornado/rmtree')
                c.command('brew', 'trust', 'beeftornado/rmtree', check=False)
            install(c, 'brew', packages('nix/' + name))
    _make(_name)


@task()
def install_linux_brew_core_packages(c):
    sequence(c, 'install_nix_brew_runtimes', 'install_nix_brew_core_packages')


TASKS['install_linux_brew_extra_packages'] = TASKS['install_nix_brew_extra_packages']


@task()
def install_nix_brew_packages(c):
    sequence(c, 'install_nix_brew_core_packages', 'install_nix_brew_extra_packages')


@task()
def brew_cleanup(c):
    c.command('brew', 'cleanup')


@task()
def brew_bundle_cleanup(c):
    c.command('brew', 'bundle', 'dump')
    c.command('brew', 'bundle', '--force', 'cleanup')
