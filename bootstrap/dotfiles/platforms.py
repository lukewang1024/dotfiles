"""OS-specific operations under the shared Python task/command runner."""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys
import tarfile

from .engine import Failure, Skip
from .tasks import DATA, PACKAGES, install, links, packages, sequence, task


@task()
def apply_linux_app_configs(c):
    c.task('apply_nix_app_configs')
    links(c, 'linux/apply_linux_app_configs')
    for unit in (c.repo / 'config/systemd/user').iterdir():
        if unit.is_file():
            c.link(unit, c.config / 'systemd/user' / unit.name)
    c.mkdir(c.cache / 'polipo')
    c.mkdir(c.home / 'Recordings')
    custom = c.repo / 'config/x/.Xresources.d/custom'
    if not custom.exists():
        c.write(custom, '')
    for desktop in ('i3-systemd', 'xfce-systemd'):
        c.copy(c.repo / 'config/xsessions' / (desktop + '.desktop'), Path('/usr/share/xsessions') / (desktop + '.desktop'), privileged=True)
    c.command('fc-cache', '-f', '-v')


@task()
def fix_ENOSPC(c):
    target = Path('/etc/sysctl.d/40-max-user-watches.conf')
    c.write(target, 'fs.inotify.max_user_watches=524288\n', mode=0o644, privileged=True)
    c.command('sudo', 'sysctl', '--system')


@task()
def fix_locale(c):
    c.command('sudo', 'localedef', '-i', 'en_US', '-f', 'UTF-8', 'en_US.UTF-8')


@task()
def install_st(c):
    dest = c.cache / 'dotfiles/st'
    c.sync_repo(dest, 'https://github.com/lukewang1024/st')
    c.command('sudo', 'make', 'install', cwd=dest)


@task()
def install_flatpak_packages(c):
    raise Skip('The Flatpak package list is empty')


@task()
def config_pacman(c):
    c.command('timedatectl', 'set-ntp', 'true')
    c.command('sudo', 'pacman-mirrors', '-c', 'Hong_Kong,Taiwan')


@task()
def set_default_apps(c):
    for mime in ('text/html', 'x-scheme-handler/http', 'x-scheme-handler/https'):
        c.command('xdg-mime', 'default', 'firefox.desktop', mime)
    c.command('xdg-mime', 'default', 'Thunar.desktop', 'inode/directory')


@task()
def setup_fcitx_rime(c):
    install(c, 'apt', packages('debian/setup_fcitx_rime'))
    c.command('im-config', '-n', 'fcitx')
    c.command('systemctl', '--user', 'daemon-reload')
    c.command('systemctl', '--user', 'enable', 'fcitx.service')
    c.note('Log out and back in to activate fcitx-rime.')


@task()
def debian_add_PPAs(c, *ppas):
    for ppa in ppas or packages('debian/prepare_debian_env_gui_extra', 'ppas'):
        c.command('sudo', 'add-apt-repository', '-y', ppa)


def linux_category(c, platform, tier):
    group = platform + '/prepare_' + platform + '_env_' + tier
    if platform == 'debian' and tier == 'gui_extra':
        c.task('debian_add_PPAs')
        key = c.download('https://download.sublimetext.com/sublimehq-pub.gpg', c.cache / 'dotfiles/sublimehq-pub.asc')
        c.command('sudo', 'mkdir', '-p', '/etc/apt/keyrings')
        c.copy(key, '/etc/apt/keyrings/sublimehq-pub.asc', privileged=True)
        c.write('/etc/apt/sources.list.d/sublime-text.sources',
                'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc\n',
                mode=0o644, privileged=True)
    install(c, 'apt' if platform == 'debian' else 'pacman', packages(group))
    if platform == 'arch':
        if tier.startswith('cli'):
            c.command('yay', '--save', '--nocleanmenu', '--nodiffmenu', '--noupgrademenu', '--noremovemake')
        install(c, 'aur', packages(group, index=1))
    if tier == 'cli_core':
        c.task('install_linuxbrew')
        c.task('install_linux_brew_core_packages' if platform == 'debian' else 'install_nix_brew_runtimes')
        sequence(c, 'core_env_setup', 'apply_linux_app_configs', 'fix_ENOSPC')
        if platform == 'debian':
            c.task('fix_locale')
    elif tier == 'cli_extra':
        if platform == 'debian':
            c.task('install_linux_brew_extra_packages')
        c.task('extra_env_setup')
        if platform == 'arch':
            c.command('sudo', 'systemctl', 'enable', '--now', 'snapd.socket')
    elif tier == 'gui_core':
        if platform == 'debian':
            c.task('setup_fcitx_rime')
        else:
            sequence(c, 'install_st', 'set_default_apps')
    elif platform == 'debian':
        c.task('install_st')


@task()
def setup_arch_gaming(c):
    install(c, 'pacman', packages('arch/setup_arch_gaming'))
    install(c, 'aur', packages('arch/setup_arch_gaming', index=1))


@task()
def prepare_chromeos(c):
    if not c.exists('crew'):
        c.installer('https://git.io/vddgY', 'bash')
    c.command('crew', 'update')
    c.command('crew', 'upgrade')
    install(c, 'crew', packages('chromeos/prepare_chromeos'))
    c.task('env_setup')


@task()
def check_admin(c):
    groups = c.command('id', '-G', capture=True)
    if not c.dry_run and not ({'544', '0'} & set(groups.split())):
        raise Failure('Run Cygwin from an administrator terminal')


@task()
def setup_cygwin_env(c):
    dest = Path('/etc/fstab')
    if dest.exists():
        text = dest.read_text(encoding='utf-8').replace('none /cygdrive cygdrive binary,posix=0,user 0 0', 'none / cygdrive binary,posix=0,user 0 0')
        c.backup(dest)
        c.write(dest, text, mode=0o644)
    links(c, 'cygwin/setup_cygwin_env')
    win_home = c.command('cygpath', '-H', capture=True).strip()
    passwd = c.command('mkpasswd', '-l', '-d', '-p', win_home or '<windows-home>', capture=True)
    group = c.command('mkgroup', '-l', '-d', capture=True)
    c.write('/etc/passwd', passwd, mode=0o644)
    c.write('/etc/group', group, mode=0o644)


@task()
def install_sage(c):
    dest = c.data / 'sage'
    c.sync_repo(dest, 'https://github.com/svnpenn/sage')
    c.link(dest, c.home / '.sage')
    c.command(dest / 'install.sh')


@task()
def install_cygwin_packages(c):
    c.command('sage', 'update')
    install(c, 'sage', packages('cygwin/install_cygwin_packages'))


def macos_category(c, tier):
    group = 'macos/prepare_macos_env_' + tier
    if tier == 'cli_core':
        sequence(c, 'install_homebrew', 'install_nix_brew_runtimes', 'install_nix_brew_core_packages')
    elif tier == 'cli_extra':
        c.task('install_nix_brew_extra_packages')
    if tier == 'gui_extra':
        c.command('mas', 'install', *packages(group, 'masApps'))
        c.command('mas', 'upgrade')
    for variable, flags in [('pkgs', []), ('casks', ['--cask']), ('no_quarantined_casks', ['--cask', '--no-quarantine'])]:
        if variable in PACKAGES[group]:
            install(c, 'brew', packages(group, variable), *flags)
    if tier == 'cli_core':
        c.task('core_env_setup')
    elif tier == 'cli_extra':
        c.task('extra_env_setup')
    elif tier == 'gui_core':
        sequence(c, 'rime_setup', 'set_macos_configs')


@task()
def set_macos_configs(c):
    c.task('apply_nix_app_configs')
    links(c, 'macos/set_macos_configs')
    c.command('defaults', 'write', 'org.hammerspoon.Hammerspoon', 'MJConfigFile', c.config / 'hammerspoon/workbench-init.lua')
    c.copy(c.repo / 'config/RectangleApp/RectangleConfig.json', c.home / 'Library/Application Support/Rectangle/RectangleConfig.json')
    c.command(sys.executable, c.repo / 'config/hyper/migrate_rectangle.py', '--apply')
    c.command(c.repo / 'util/macos/setup-launchagent', '--label', 'com.lukew.rust-target-prune', '--command', str(c.bin / 'rust-target-prune') + ' --apply', '--hours', '3')
    sequence(c, 'setup_alfred_prefs', 'retire_peon_relay_agent', 'brew_multi_user_permission',
             'fix_battery_drain_over_sleep', 'better_macos_defaults')


@task()
def setup_alfred_prefs(c):
    if c.command(c.repo / 'util/macos/alfred-prefs-folder', check=False):
        c.note('Open Alfred once, then rerun alfred-prefs-folder.')


@task()
def retire_peon_relay_agent(c):
    if (c.home / 'Library/LaunchAgents/com.lukew.peon-relay.plist').exists():
        c.command(c.repo / 'util/macos/setup-launchagent', '--uninstall', '--label', 'com.lukew.peon-relay')
    local = c.home / '.ssh/config.local'
    if local.exists():
        old = local.read_text(encoding='utf-8')
        new = re.sub(r'^\s*RemoteForward\s+(?:localhost:)?19998(?:\s[^\n]*)?\n?', '', old, flags=re.M)
        if old != new:
            c.write(local, new)


@task()
def brew_multi_user_permission(c):
    values = list(Path('/usr/local').glob('*'))
    if values:
        c.command('sudo', 'chmod', '-R', 'g+w', *values)


@task()
def fix_battery_drain_over_sleep(c):
    c.command('sudo', 'pmset', '-b', 'tcpkeepalive', '0')


@task()
def better_macos_defaults(c):
    c.command('osascript', '-e', 'tell application "System Preferences" to quit')
    c.command('sudo', 'nvram', 'StartupMute=%00')
    c.command('/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister',
              '-kill', '-r', '-domain', 'local', '-domain', 'system', '-domain', 'user')
    for argv in json.loads((DATA / 'macos-defaults.json').read_text(encoding='utf-8')):
        c.command(*[c.expand(arg) if arg.startswith('~/') or '${HOME}' in arg else arg for arg in argv])
    c.command('chflags', 'nohidden', c.home / 'Library')
    # Use the supported reset preference rather than deleting OS cache trees.
    c.command('defaults', 'write', 'com.apple.dock', 'ResetLaunchPad', '-bool', 'true')
    c.command('/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings', '-u')
    for app in ('Activity Monitor', 'Address Book', 'Calendar', 'cfprefsd', 'Contacts', 'Dock', 'Finder',
                'Google Chrome Canary', 'Google Chrome', 'Mail', 'Messages', 'Opera', 'Photos', 'Safari', 'SystemUIServer'):
        c.command('killall', app, check=False)
    c.note('Some macOS settings require logout or restart.')


@task()
def install_mac_wechat_plugin(c):
    dest = c.cache / 'dotfiles/WeChatPlugin-MacOS'
    c.sync_repo(dest, 'https://github.com/TKkk-iOSer/WeChatPlugin-MacOS')
    c.command(dest / 'Other/Install.sh', interactive=True)


@task()
def backup_automator_stuff(c):
    for source, target in [('Library/Services', 'Services'), ('Applications/Automator', 'Applications')]:
        c.command('rsync', '-au', str(c.home / source) + '/', c.home / 'Dropbox/Sync/Automator' / target, '--progress')


@task()
def setup_macos_gaming(c):
    install(c, 'brew', packages('macos/setup_macos_gaming', 'casks'), '--cask')
    c.task('brew_cleanup')


@task()
def install_scoop(c):
    if c.exists('scoop'):
        c.command('scoop', 'update')
    else:
        c.ps('Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force')
        c.installer('https://get.scoop.sh', 'powershell', interactive=True)
        c.refresh_path()
    c.command('scoop', 'install', 'git')
    for bucket in packages('windows/install_scoop', 'buckets'):
        c.command('scoop', 'bucket', 'add', bucket)
    c.command('scoop', 'bucket', 'add', 'customize', 'https://github.com/ChinLong/scoop-customize.git')


@task()
def install_winget(c):
    if not c.exists('winget'):
        c.ps("Start-Process 'ms-appinstaller:?source=https://aka.ms/getwinget'")
        c.prompt('Finish installing App Installer, then press Enter')
        c.refresh_path()
        if not c.dry_run and not c.exists('winget'):
            raise Failure('winget is still unavailable after installing App Installer')


@task()
def set_windows_links(c):
    links(c, 'windows/set_windows_configs')
    c.task('git_hooks_setup')


@task()
def set_windows_configs(c):
    c.command('sudo', 'reg', 'add', r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock',
              '/t', 'REG_DWORD', '/f', '/v', 'AllowDevelopmentWithoutDevLicense', '/d', '1')
    c.command('sudo', *c.powershell_argv("$ErrorActionPreference='Stop'; Set-Service ssh-agent -StartupType Automatic"))
    c.task('set_windows_links')
    c.command('git', 'config', '--global', 'core.sshCommand', 'C:/Windows/System32/OpenSSH/ssh.exe')
    c.ps("[Environment]::SetEnvironmentVariable('GIT_SSH', 'C:/Windows/System32/OpenSSH/ssh.exe', 'User')")


def windows_category(c, tier):
    group = 'windows/prepare_windows_env_' + tier
    if tier == 'cli_core':
        sequence(c, 'install_scoop', 'install_winget')
    install(c, 'scoop', packages(group))
    if 'fonts' in PACKAGES[group]:
        install(c, 'scoop-fonts', packages(group, 'fonts'))
    install(c, 'winget', packages(group, 'wingetPkgs'))
    if tier == 'gui_core':
        c.task('set_windows_configs')


@task()
def prepare_windows_gaming(c):
    install(c, 'scoop', packages('windows/prepare_windows_gaming'))


# Public task names remain compatible with `init run <module> <function>`.
for _platform in ('macos', 'debian', 'arch', 'windows'):
    for _tier in ('cli_core', 'cli_extra', 'gui_core', 'gui_extra'):
        def _register(platform, tier):
            @task(f'prepare_{platform}_env_{tier}')
            def category(c):
                if platform == 'macos':
                    macos_category(c, tier)
                elif platform == 'windows':
                    windows_category(c, tier)
                else:
                    linux_category(c, platform, tier)
        _register(_platform, _tier)
    for _mode in ('core', 'cli', 'gui'):
        def _register_group(platform, mode):
            @task(f'prepare_{platform}_env_{mode}')
            def category(c):
                for tier in {'core': ('cli_core', 'gui_core'), 'cli': ('cli_core', 'cli_extra'), 'gui': ('gui_core', 'gui_extra')}[mode]:
                    c.task(f'prepare_{platform}_env_{tier}')
                if platform in ('macos', 'debian') or platform == 'arch' and mode != 'gui':
                    c.task('brew_cleanup')
        _register_group(_platform, _mode)
    def _register_root(platform):
        @task(f'prepare_{platform}_env')
        def root(c, mode='core'):
            if platform == 'arch':
                c.task('config_pacman')
            if mode == 'all':
                sequence(c, f'prepare_{platform}_env_cli', f'prepare_{platform}_env_gui')
            elif mode in ('core', 'cli', 'gui'):
                c.task(f'prepare_{platform}_env_{mode}')
            elif mode == 'game':
                c.task('prepare_windows_gaming' if platform == 'windows' else f'setup_{platform}_gaming')
            else:
                raise Failure(f'Unsupported {platform} mode: {mode}')
    _register_root(_platform)


TERMUX_PACKAGES = ('ca-certificates curl diff-so-fancy fd file fzf git jq krb5 less nano openssh python ripgrep rsync rust '
                   'starship termux-api termux-services tig tmux tree unzip vim which zip zoxide zsh').split()


@task()
def install_termux_core_packages(c):
    c.command('pkg', 'update', '-y')
    install(c, 'pkg', TERMUX_PACKAGES, '-y')


@task()
def termux_shell_setup(c):
    for source, target in [('.zshenv', '.zshenv'), ('termux.properties', '.termux/termux.properties'), ('colors.properties', '.termux/colors.properties')]:
        c.link(c.repo / 'config/termux' / source, c.home / target)
    if c.dry_run or c.exists('termux-reload-settings'):
        c.command('termux-reload-settings')


@task()
def termux_basic_setup(c):
    sequence(c, 'basic_env_setup', 'termux_shell_setup')


@task()
def termux_default_shell_setup(c):
    c.task('set_default_shell', 'zsh')


@task()
def termux_ssh_setup(c):
    c.mkdir(c.home / '.ssh')
    if not c.dry_run:
        (c.home / '.ssh').chmod(0o700)
    if not (c.home / '.ssh/id_ed25519').exists():
        c.command('ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', c.home / '.ssh/id_ed25519')
    c.command('sv-enable', 'sshd')
    c.command('sv-enable', 'ssh-agent')


@task()
def prepare_termux_env(c, mode='core'):
    if mode not in ('core', 'all'):
        raise Failure('Termux supports basic, core, all, and sync')
    if mode == 'all':
        c.note('Termux has no extra package set; using core.')
    sequence(c, 'install_termux_core_packages', 'termux_default_shell_setup', 'zinit_install',
             'termux_basic_setup', 'tmux_plugins_setup')
    if c.dry_run or c.exists('tmux-agent-workbench'):
        c.command('tmux-agent-workbench', 'client', 'setup', 'termux')
    else:
        c.note('tmux-agent-workbench unavailable; mobile notifications are not configured')
    sequence(c, 'vim_plugins_setup', 'termux_ssh_setup', 'setup_distributed_workbench')
    c.note('Public SSH key: ' + str(c.home / '.ssh/id_ed25519.pub'))


@task()
def setup_distributed_workbench(c):
    if c.platform == 'termux':
        c.task('setup_termux_workbench_peer')
    elif c.platform == 'windows':
        c.installer('https://raw.githubusercontent.com/lukewang1024/distributed-workbench/main/scripts/install-from-release.ps1', 'powershell', 'latest')
    elif c.platform in ('macos', 'debian', 'arch', 'chromeos'):
        c.installer('https://raw.githubusercontent.com/lukewang1024/distributed-workbench/main/scripts/install-from-release.sh', 'sh', 'latest')
    else:
        raise Failure('Distributed Workbench is not supported on ' + c.platform)


@task()
def setup_termux_workbench_peer(c):
    root = c.config / 'distributed-workbench'
    config = root / 'peer.conf'
    old = root / 'termux-peer.conf'
    if not config.exists() and old.exists():
        c.copy(old, config)
    values = {}
    source = config if config.exists() else old
    if source.exists():
        values = dict(line.split('=', 1) for line in source.read_text(encoding='utf-8').splitlines() if '=' in line and not line.startswith('#'))
    if not values:
        peer = c.prompt('SSH alias for an existing workbench node (blank to skip)', 'peer' if c.dry_run else '')
        if not peer:
            raise Skip('No workbench peer selected')
        model = c.command('getprop', 'ro.product.model', capture=True).strip() or 'termux'
        node = re.sub(r'[^a-z0-9._-]+', '-', model.lower()).strip('-') + '-termux'
        values = dict(DISTRIBUTED_WORKBENCH_PEER_HOST=peer, DISTRIBUTED_WORKBENCH_NODE_ID=node, DISTRIBUTED_WORKBENCH_VERSION='latest')
        c.write(config, ''.join(k + '=' + v + '\n' for k, v in values.items()))
    peer = values.get('DISTRIBUTED_WORKBENCH_PEER_HOST', '')
    node = values.get('DISTRIBUTED_WORKBENCH_NODE_ID', values.get('DISTRIBUTED_WORKBENCH_TERMUX_NODE_ID', ''))
    version = values.get('DISTRIBUTED_WORKBENCH_VERSION', 'latest')
    if any(not re.fullmatch(r'[0-9A-Za-z._-]+', v) for v in (peer, node, version)):
        raise Failure('Invalid peer, node ID, or version in workbench peer.conf')
    ssh = ['ssh', '-o', 'BatchMode=yes', '-o', 'ClearAllForwardings=yes', peer]
    c.command(*ssh, 'true')
    env = dict(DISTRIBUTED_WORKBENCH_CONTROLLER_ID=node, DISTRIBUTED_WORKBENCH_EXECUTOR_ID=node + '-rust')
    installer = c.download('https://raw.githubusercontent.com/lukewang1024/distributed-workbench/main/scripts/install-from-release.sh',
                           c.cache / 'distributed-workbench/install-from-release.sh')
    rc = c.command('sh', installer, version, c.home, env=env, check=False)
    if rc:
        output = c.command(*ssh, '"$HOME/.local/bin/workbench" --version', capture=True, expand=False)
        words = output.split()
        if len(words) < 2:
            raise Failure('Peer returned an empty or invalid version')
        version = words[1]
        if not re.fullmatch(r'[0-9A-Za-z._-]+', version):
            raise Failure('Peer returned an invalid version')
        archive = c.cache / 'distributed-workbench/termux-current.tar.gz'
        # Binary transfer uses an explicit output file, not a text capture.
        remote = 'cat "${XDG_CACHE_HOME:-$HOME/.cache}/distributed-workbench-bootstrap/termux-current.tar.gz"'
        c.record('download-peer-artifact', peer=peer, target=str(archive))
        c.command(*ssh, remote, output_file=archive)
        if not c.dry_run:
            unpack = c.cache / 'distributed-workbench/bootstrap'
            with tarfile.open(archive) as tar:
                # Only regular files/directories; reject traversal and links.
                for member in tar.getmembers():
                    dest = (unpack / member.name).resolve()
                    if not dest.is_relative_to(unpack.resolve()) or not (member.isfile() or member.isdir()):
                        raise Failure('Unsafe peer bootstrap archive member')
                tar.extractall(unpack)
            bundle = unpack / f'distributed-workbench-{version}-aarch64-linux-android'
            c.command('sh', bundle / 'scripts/install-termux-user.sh', bundle / 'bin/workbench', node + '-rust', c.home, env=env)
    c.command(c.bin / 'connect-termux-peer', peer, node)
