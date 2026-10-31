"""Harmless, cross-platform tests. Never execute a package manager."""
from contextlib import redirect_stdout, redirect_stderr
import io
import json
import base64
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'bootstrap'))
sys.dont_write_bytecode = True
from dotfiles.cli import PLATFORMS, select_tasks, main
from dotfiles.engine import Context, Failure, Reporter, detect_platform
from dotfiles.tasks import TASKS, PACKAGES, LINKS, install, language_packages, platform_packages


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / 'test-user'
        self.home.mkdir()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith('XDG_')}
        self.env.update(XDG_CONFIG_HOME=str(self.home / 'config'), XDG_DATA_HOME=str(self.home / 'data'),
                        XDG_STATE_HOME=str(self.home / 'state'), XDG_CACHE_HOME=str(self.home / 'cache'))
        self.env.update(HOME=str(self.home), USERPROFILE=str(self.home),
                        APPDATA=str(self.home / 'roaming'), LOCALAPPDATA=str(self.home / 'local'))
        self.env.pop('LANG', None)

    def context(self, platform='debian', dry=True, reporter=None):
        c = Context(ROOT, platform, home=self.home, env=self.env, dry_run=dry, reporter=reporter)
        c.tasks = dict(TASKS)
        return c

    def test_all_platform_core_all_basic_sync_plans_have_no_effects(self):
        before = sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*'))
        with patch('subprocess.Popen', side_effect=AssertionError('dry run spawned a command')), \
             patch('dotfiles.engine.urlopen', side_effect=AssertionError('dry run accessed network')):
            for platform in PLATFORMS:
                for mode in ('basic', 'core', 'all', 'sync'):
                    with self.subTest(platform=platform, mode=mode):
                        c = self.context(platform)
                        for name, arguments in select_tasks(platform, mode, []):
                            c.task(name, *arguments)
                        self.assertTrue(c.events)
                        self.assertTrue(any(e['kind'] == 'link' for e in c.events))
                        self.assertFalse(any(e['kind'] == 'command' and Path(e['argv'][0]).name == 'ssh-keygen'
                                             for e in c.events))
        after = sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*'))
        self.assertEqual(before, after)

    def test_package_and_link_data_preserve_legacy_inventory(self):
        legacy = json.loads((ROOT / 'tests/fixtures/bootstrap-inventory.json').read_text(encoding='utf-8'))
        self.assertEqual(PACKAGES, {k: v['arrays'] for k, v in legacy.items() if v['arrays']})
        # Keep the legacy inventory assertion while allowing new optional helpers.
        links = {k: [entry for entry in entries
                     if entry[0] not in ('$util_dir/shell/ssh-setup', '$util_dir/shell/ssh-pair')]
                 for k, entries in LINKS.items()}
        self.assertEqual(links, {k: v['links'] for k, v in legacy.items() if v['links']})
        for helper in ('ssh-setup', 'ssh-pair'):
            self.assertTrue(any([f'$util_dir/shell/{helper}', f'$bin_dir/{helper}'] in entries
                                for entries in LINKS.values()))

    def test_ish_core_installs_shared_tools_and_gssapi_client(self):
        c = self.context('ish')
        for name, arguments in select_tasks('ish', 'core', []):
            c.task(name, *arguments)
        commands = [e['argv'] for e in c.events if e['kind'] == 'command']
        packages = next(a for a in commands if a[:2] == ['apk', 'add'])
        self.assertIn('openssh-client-krb5', packages)
        self.assertNotIn('ripgrep', packages)
        self.assertNotIn('starship', packages)
        for name in ('krb5', 'zsh', 'git', 'vim', 'tmux', 'python3'):
            self.assertIn(name, packages)
        for a in commands:
            self.assertNotIn(a[0], ('sudo', 'sv-enable', 'uv', 'machine-fabric', 'codex'))
            self.assertNotIn('openssh-server', a)
            self.assertNotIn('openssh-client-default', a)
        task_names = [e['name'] for e in c.events if e['kind'] == 'task']
        for name in ('zinit_install', 'basic_env_setup', 'util_setup', 'git_setup', 'tmux_plugins_setup',
                     'workbench_setup', 'agent_team_setup', 'vim_plugins_setup', 'ssh_setup'):
            self.assertIn(name, task_names)
        for name in ('termux_ssh_setup', 'setup_machine_fabric'):
            self.assertNotIn(name, task_names)

    def test_ish_and_termux_install_the_same_shared_helpers(self):
        def shared_links(platform, task):
            c = self.context(platform)
            c.task(task)
            return {e['target'] for e in c.events if e['kind'] == 'link'
                    and ROOT / 'util/termux' not in Path(e['source']).parents
                    and ('/bin/' in e['target'] or 'AGENTS.md' in e['target'] or 'CLAUDE.md' in e['target'])}
        termux = shared_links('termux', 'termux_basic_setup')
        ish = shared_links('ish', 'ish_basic_setup')
        self.assertTrue(termux)
        self.assertEqual(termux - ish, set())

    def test_workbench_fresh_install_and_repair_are_available_on_mobile(self):
        for platform in ('ish', 'termux'):
            with self.subTest(platform=platform):
                c = self.context(platform)
                for name, arguments in select_tasks(platform, 'workbench', []):
                    c.task(name, *arguments)
                commands = [e['argv'] for e in c.events if e['kind'] == 'command']
                root = c.data / 'tmux/plugins/tmux-agent-workbench'
                self.assertIn(['git', 'clone', '--depth', '1',
                               'https://github.com/lukewang1024/tmux-agent-workbench.git', str(root)], commands)
                self.assertIn([str(root / 'install'), str(c.bin)], commands)
                self.assertIn([str(c.bin / 'tmux-agent-workbench'), '--version'], commands)

    def test_agent_team_default_checkout_uses_xdg(self):
        c = self.context('ish')
        c.env.pop('AGENT_TEAM_REPO', None)
        c.task('agent_team_setup')
        commands = [e['argv'] for e in c.events if e['kind'] == 'command']
        self.assertIn([sys.executable, str(c.data / 'agent-team/install.py'), '--bin-dir', str(c.bin)], commands)

    def test_ish_installed_packages_skip_network_and_install(self):
        c = self.context('ish', dry=False)
        read_text = Path.read_text
        calls = []
        def text(path, *args, **kwargs):
            if str(path) == '/etc/alpine-release':
                return '3.24.3\n'
            if str(path) == '/etc/apk/repositories':
                return ('https://dl-cdn.alpinelinux.org/alpine/v3.24/main\n'
                        'https://dl-cdn.alpinelinux.org/alpine/v3.24/community\n')
            return read_text(path, *args, **kwargs)
        def command(*args, **kwargs):
            calls.append((args, kwargs))
            return 'x86' if args == ('apk', '--print-arch') else 0
        with patch('dotfiles.ish.os.geteuid', return_value=0), \
             patch.object(Path, 'read_text', autospec=True, side_effect=text), \
             patch.object(c, 'command', side_effect=command):
            c.task('install_ish_core_packages')
        self.assertFalse(any(args[:2] in (('apk', 'update'), ('apk', 'add')) for args, _ in calls))
        self.assertTrue(any(args[0] == 'ssh' for args, _ in calls))

    def test_ish_apk_compat_is_scoped_to_install_commands(self):
        c = self.context('ish', dry=False)
        inherited_preload = c.env.get('LD_PRELOAD')
        compat = c.data / 'dotfiles/ish-compat/libapk-compat.so'
        compat.parent.mkdir(parents=True)
        compat.touch()
        read_text = Path.read_text
        calls = []
        def text(path, *args, **kwargs):
            if str(path) == '/etc/alpine-release':
                return '3.24.3\n'
            if str(path) == '/etc/apk/repositories':
                return ('https://dl-cdn.alpinelinux.org/alpine/v3.24/main\n'
                        'https://dl-cdn.alpinelinux.org/alpine/v3.24/community\n')
            return read_text(path, *args, **kwargs)
        def command(*args, **kwargs):
            calls.append((args, kwargs))
            if args == ('apk', '--print-arch'):
                return 'x86'
            if args[:3] == ('apk', 'info', '-e') and len(args) > 4:
                return 1
            return 0
        with patch('dotfiles.ish.os.geteuid', return_value=0), \
             patch.object(Path, 'read_text', autospec=True, side_effect=text), \
             patch.object(c, 'command', side_effect=command):
            c.task('install_ish_core_packages')
        installs = [(args, options) for args, options in calls if args[:2] in (('apk', 'update'), ('apk', 'add'))]
        self.assertEqual(len(installs), 2)
        for args, options in installs:
            expected = str(compat) + (':' + inherited_preload if inherited_preload else '')
            self.assertEqual(options['env']['LD_PRELOAD'], expected)
        self.assertEqual(c.env.get('LD_PRELOAD'), inherited_preload)
        self.assertTrue(all('env' not in options for args, options in calls if args[0] == 'ssh'))

    def test_ish_detection_requires_emulator_and_alpine(self):
        with patch.dict(os.environ, {'TERMUX_VERSION': '', 'PREFIX': ''}), \
             patch('dotfiles.engine.os.uname', create=True) as uname, \
             patch('dotfiles.engine.Path.exists', lambda p: str(p) == '/etc/alpine-release'), \
             patch('dotfiles.engine.sys.platform', 'linux'):
            uname.return_value.release = '4.20.69-ish'
            self.assertEqual(detect_platform(), 'ish')
            uname.return_value.release = '6.1.0'
            with self.assertRaises(Failure):
                detect_platform()

    def test_ish_sync_preserves_kerberos_and_ssh_local_overrides(self):
        c = self.context('ish', dry=False)
        conf = c.config / 'ish-kerberos'
        conf.mkdir(parents=True)
        (conf / 'user.conf').write_text('KRB5_REALM=LOCAL.TEST\n')
        (conf / 'krb5.conf').write_text('# administrator profile\n')
        ssh = c.home / '.ssh/config'
        ssh.parent.mkdir()
        ssh.write_text('Host local-alias\n  HostName server.example\n')
        c.bin.mkdir(parents=True)
        (c.bin / 'ish-connect').symlink_to(ROOT / 'util/ish/ish-connect')
        c.task('ish_client_setup')
        first = ssh.read_text()
        c.task('ish_client_setup')
        self.assertEqual(ssh.read_text(), first)
        self.assertTrue(first.startswith('Host local-alias\n'))
        self.assertIn('config/ish/ssh_config', first)
        self.assertEqual((conf / 'krb5.conf').read_text(), '# administrator profile\n')
        self.assertEqual((conf / 'user.conf').read_text(), 'KRB5_REALM=LOCAL.TEST\n')
        self.assertTrue((c.bin / 'ssh-connect').is_symlink())
        self.assertEqual((c.bin / 'kinit-auto-login').resolve(), ROOT / 'util/kerberos/kinit-auto-login')
        self.assertFalse((c.bin / 'ish-connect').is_symlink())

    def test_ish_profile_produces_workbench_ssh_alias_and_mapping(self):
        c = self.context('ish', dry=False)
        conf = c.config / 'ish-kerberos'
        conf.mkdir(parents=True)
        profile = ('KRB5_REALM=ISH.TEST\nKRB5_PRINCIPAL=testuser@ISH.TEST\n'
                   'SSH_HOST=ssh.ish.test\nSSH_USER=testuser\nSSH_PORT=2222\nTMUX_SESSION=mobile\n')
        (conf / 'user.conf').write_text(profile)
        ssh = c.home / '.ssh/config'
        ssh.parent.mkdir()
        ssh.write_text('Host local-alias\n  HostName local.example\n  User custom\n')
        c.task('ish_client_setup')
        mapping = c.config / 'ssh/kerberos'
        self.assertIn('ssh.ish.test testuser@ISH.TEST mobile', mapping.read_text())
        self.assertEqual((conf / 'user.conf').read_text(), profile)
        before = {p: p.read_bytes() for p in (ssh, mapping, conf / 'ssh_config')}
        c.task('ish_client_setup')
        self.assertEqual({p: p.read_bytes() for p in before}, before)
        if shutil.which('ssh'):
            settings = subprocess.check_output(['ssh', '-G', '-F', str(ssh), 'ssh.ish.test'], text=True)
            for value in ('user testuser', 'hostname ssh.ish.test', 'port 2222',
                          'gssapiauthentication yes', 'passwordauthentication no',
                          'serveraliveinterval 5'):
                self.assertIn(value + '\n', settings)
            local = subprocess.check_output(['ssh', '-G', '-F', str(ssh), 'local-alias'], text=True)
            self.assertIn('hostname local.example\n', local)
            self.assertIn('user custom\n', local)
            self.assertIn('port 22\n', local)

    def test_ish_profile_preserves_explicit_shared_mapping_and_rejects_injection(self):
        c = self.context('ish', dry=False)
        conf = c.config / 'ish-kerberos'
        conf.mkdir(parents=True)
        profile = ('KRB5_REALM=ISH.TEST\nKRB5_PRINCIPAL=testuser@ISH.TEST\n'
                   'SSH_HOST=ssh.ish.test\nSSH_USER=testuser\n')
        (conf / 'user.conf').write_text(profile)
        mapping = c.config / 'ssh/kerberos'
        mapping.parent.mkdir()
        original = '# local mapping\nssh.ish.test other@ISH.TEST custom\n'
        mapping.write_text(original)
        c.task('ish_ssh_profile_setup')
        self.assertEqual(mapping.read_text(), original)
        (conf / 'user.conf').write_text(profile.replace('SSH_HOST=ssh.ish.test', 'SSH_HOST=*.test'))
        with self.assertRaises(Failure):
            c.task('ish_ssh_profile_setup')
        self.assertEqual(mapping.read_text(), original)

    def test_ish_login_restores_tools_after_system_profile_resets_path(self):
        c = self.context('ish', dry=False)
        env = dict(c.env, DOTFILES_PLATFORM='ish', DOTFILES_HOME=str(ROOT),
                   KRB5CCNAME='FILE:/private/existing-ticket', PATH=os.environ['PATH'])
        result = subprocess.run(['sh', '-c',
                                 'PATH=/usr/bin:/bin; . "$DOTFILES_HOME/config/zsh/.zprofile"; '
                                 'printf "%s\\n%s\\n" "$PATH" "$KRB5CCNAME"'],
                                env=env, capture_output=True, text=True, check=True)
        self.assertIn(str(c.bin), result.stdout.splitlines()[0].split(':'))
        self.assertEqual(result.stdout.splitlines()[1], 'FILE:/private/existing-ticket')

    def test_ish_installs_login_wrapper_only_with_compat_library(self):
        c = self.context('ish', dry=False)
        c.task('ish_client_setup')
        self.assertFalse((c.bin / 'zsh').exists())
        library = c.data / 'dotfiles/ish-compat/libncurses-compat.so'
        library.parent.mkdir(parents=True)
        library.touch()
        c.task('ish_client_setup')
        self.assertEqual((c.bin / 'zsh').resolve(), ROOT / 'util/ish/zsh')

    def test_ish_login_wrapper_is_not_skipped_for_system_zsh(self):
        from dotfiles.tasks import set_default_shell
        c = self.context('ish', dry=False)
        c.bin.mkdir(parents=True)
        (c.bin / 'zsh').symlink_to(ROOT / 'util/ish/zsh')
        c.env['SHELL'] = '/bin/zsh'
        c.env['USER'] = 'root'
        with patch.object(c, 'exists', return_value=True), \
             patch.object(c, 'command', return_value='root:x:0:0:root:/root:/bin/zsh') as command, \
             patch.object(c, 'write'):
            set_default_shell(c)
        self.assertTrue(any(call.args[:3] == ('chsh', '-s', str(c.bin / 'zsh'))
                            for call in command.call_args_list))

    def test_ish_kerberos_decline_keeps_existing_profile(self):
        c = self.context('ish', dry=False)
        c.task('ish_client_setup')
        profile = c.config / 'ish-kerberos/krb5.conf'
        profile.write_text('# preserve this\n')
        answers = iter(['ISH.TEST', 'testuser@ISH.TEST', 'dns', 'ssh.ish.test', 'testuser', '22', 'dev', 'no'])
        c.prompt = lambda *a: next(answers)
        c.task('ish_kerberos')
        self.assertEqual(profile.read_text(), '# preserve this\n')

    def test_ish_git_and_login_setup_preserve_content_on_repeat(self):
        from dotfiles.ish import append_block
        c = self.context('ish', dry=False)
        git = c.config / 'git/config'
        git.parent.mkdir(parents=True)
        content = '[user]\n  name = Example User\n  email = user@example.test\n[alias]\n  custom = status\n'
        git.write_text(content)
        c.task('git_setup', 'configure-only')
        first = git.read_text()
        c.task('git_setup', 'configure-only')
        self.assertEqual(git.read_text(), first)
        self.assertTrue(first.startswith(content))
        profile = c.home / '.profile'
        profile.write_text('export CUSTOM=keep\n')
        append_block(c, profile, 'export DOTFILES_PLATFORM=ish\n')
        first = profile.read_text()
        append_block(c, profile, 'export DOTFILES_PLATFORM=ish\n')
        self.assertEqual(profile.read_text(), first)
        self.assertTrue(first.startswith('export CUSTOM=keep\n'))

    @unittest.skipIf(os.name == 'nt', 'POSIX shell startup')
    def test_ish_login_keeps_custom_xdg_and_manual_ticket_cache_aligned(self):
        script = ('is_macos() { return 1; }; is_termux() { return 1; }; is_linux() { return 1; }; '
                  '. "$1/config/ish/env.sh"; . "$1/config/sh/xdg-paths.sh"; '
                  'printf "%s\\n" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$KRB5_CONFIG" "$KRB5CCNAME"')
        env = dict(self.env)
        env.pop('KRB5_CONFIG', None)
        env.pop('KRB5CCNAME', None)
        result = subprocess.run(['/bin/sh', '-c', script, 'sh', str(ROOT)], env=env,
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.splitlines(), [str(self.home / 'config'), str(self.home / 'data'),
                         str(self.home / 'cache'), str(self.home / 'config/ish-kerberos/krb5.conf'),
                         'FILE:' + str(self.home / 'cache/ish-kerberos/krb5cc')])

    def test_conda_is_not_installed_or_initialized_by_dotfiles(self):
        groups = [('macos/prepare_macos_env_cli_extra', 'casks'),
                  ('arch/prepare_arch_env_cli_extra', 'pkgs'),
                  ('windows/prepare_windows_env_gui_extra', 'pkgs')]
        for group, variable in groups:
            with self.subTest(group=group):
                self.assertFalse(any('conda' in name.lower() for array in PACKAGES[group][variable]
                                     for name in array))
        self.assertFalse(any('conda' in source.lower() or 'conda' in target.lower()
                             for entries in LINKS.values() for source, target in entries))
        self.assertNotIn('conda-zsh-completion', (ROOT / 'config/zsh/zinit.zshrc').read_text(encoding='utf-8'))

    def test_disabled_homebrew_casks_are_absent_from_macos_inventory(self):
        groups = ('macos/prepare_macos_env_gui_core', 'macos/prepare_macos_env_gui_extra',
                  'macos/setup_macos_gaming')
        c = self.context('macos')
        selected = {name for group in groups for name in platform_packages(c, group, 'casks')}
        self.assertTrue({'alacritty', 'openemu', 'qlcolorcode', 'qlprettypatch', 'qlstephen'}.isdisjoint(selected))

    def test_pkgconf_is_reinstalled_only_after_major_macos_upgrade(self):
        prefix = self.home / 'pkgconf'
        prefix.mkdir()
        self.env['DOTFILES_MACOS_VERSION'] = '27.0'
        for built_on, expected in (('macOS 26', True), ('macOS 27', False)):
            with self.subTest(built_on=built_on):
                (prefix / 'INSTALL_RECEIPT.json').write_text(json.dumps({'built_on': {'os_version': built_on}}))
                c = self.context('macos', dry=False)
                calls = []
                def command(*argv, **kwargs):
                    calls.append(argv)
                    return str(prefix) if argv == ('brew', '--prefix', 'pkgconf') else ''
                c.command = command
                c.task('reconcile_homebrew_pkgconf')
                self.assertEqual(('brew', 'reinstall', 'pkgconf') in calls, expected)

    def test_package_selection_does_not_mutate_catalog(self):
        before = json.dumps(PACKAGES, sort_keys=True)
        c = self.context()
        a = language_packages(c, 'install_gem_packages', 'all')
        b = language_packages(c, 'install_gem_packages', 'all')
        self.assertEqual(a, b)
        self.assertEqual(before, json.dumps(PACKAGES, sort_keys=True))

    def test_scoop_url_manifests_skip_installed_apps(self):
        c = self.context('windows', dry=False)
        current = self.home / 'scoop/apps/go-musicfox/current'
        current.mkdir(parents=True)
        calls = []
        c.command = lambda *argv, **kwargs: calls.append(argv)
        manifest = 'https://example.invalid/go-musicfox.json'
        install(c, 'scoop', ['git', manifest])
        self.assertEqual(calls, [('scoop', 'install', 'git')])
        current.rmdir()
        calls.clear()
        install(c, 'scoop', ['git', manifest])
        self.assertEqual(calls, [('scoop', 'install', 'git', manifest)])

    def test_macos_package_rules_follow_os_version(self):
        group = 'macos/prepare_macos_env_gui_core'
        extra = 'macos/prepare_macos_env_gui_extra'
        for version, present in (('26.6.1', True), ('27.0', False), ('28.0.1', False)):
            with self.subTest(version=version):
                self.env['DOTFILES_MACOS_VERSION'] = version
                c = self.context('macos')
                casks = platform_packages(c, group, 'casks')
                mas_apps = platform_packages(c, extra, 'masApps')
                self.assertEqual('jordanbaird-ice' in casks, present)
                self.assertEqual('1452453066' in mas_apps, present)

    def test_macos_disabled_casks_are_excluded_from_every_plan(self):
        for version in (None, '26.6.1', '27.0'):
            with self.subTest(version=version):
                if version is None:
                    self.env.pop('DOTFILES_MACOS_VERSION', None)
                else:
                    self.env['DOTFILES_MACOS_VERSION'] = version
                c = self.context('macos')
                self.assertNotIn('alacritty', platform_packages(c, 'macos/prepare_macos_env_gui_core', 'casks'))
                casks = platform_packages(c, 'macos/prepare_macos_env_gui_extra', 'casks')
                for name in ('qlcolorcode', 'qlprettypatch', 'qlstephen'):
                    self.assertNotIn(name, casks)
                self.assertNotIn('openemu', platform_packages(c, 'macos/setup_macos_gaming', 'casks'))

    def test_cli_can_override_macos_version_for_dry_run(self):
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(main(['--dry-run', '--json', '--platform', 'macos', '--macos-version', '27', 'gui']), 0)
        actions = json.loads(output.getvalue())['actions']
        package_commands = [event['argv'] for event in actions if event['kind'] == 'command']
        self.assertFalse(any('jordanbaird-ice' in argv for argv in package_commands))
        self.assertFalse(any('1452453066' in argv for argv in package_commands))

    def test_core_reconciles_agent_team_checkout_and_entrypoints(self):
        url = 'https://github.com/lukewang1024/agent-team.git'
        for state in ('missing', 'checkout', 'worktree'):
            with self.subTest(state=state):
                repo = self.home / 'isolated checkouts' / state / 'agent-team'
                if state == 'checkout':
                    (repo / '.git').mkdir(parents=True)
                elif state == 'worktree':
                    repo.mkdir(parents=True)
                    (repo / '.git').write_text('gitdir: /unused/dry-run-worktree\n', encoding='utf-8')
                c = self.context('debian')
                # Never inspect the real checkout inherited from the shell.
                c.env['AGENT_TEAM_REPO'] = str(repo)
                for name, arguments in select_tasks('debian', 'core', []):
                    c.task(name, *arguments)
                commands = [event['argv'] for event in c.events if event['kind'] == 'command']
                clone = ['git', 'clone', '--depth', '1', url, str(repo)]
                pull = ['git', '-C', str(repo), 'pull', '--ff-only']
                if state == 'missing':
                    self.assertIn(clone, commands)
                    self.assertNotIn(pull, commands)
                    self.assertFalse(repo.exists())  # Dry run cannot create a checkout.
                else:
                    self.assertIn(pull, commands)
                    self.assertNotIn(clone, commands)
                self.assertIn([sys.executable, str(repo / 'install.py'), '--bin-dir', str(c.bin)], commands)

    def test_machine_fabric_install_is_pinned_and_uses_release_cdn(self):
        c = self.context('debian')
        c.env.update(MACHINE_FABRIC_VERSION='0.1.25',
                     MACHINE_FABRIC_RELEASE_BASE_URL='https://example.invalid/fabric')
        c.task('setup_machine_fabric')
        downloads = [event for event in c.events if event['kind'] == 'download']
        commands = [event for event in c.events if event['kind'] == 'command']
        self.assertEqual(len(downloads), 1)
        self.assertIn('machine-fabric/main/scripts/install-from-release.sh', downloads[0]['url'])
        self.assertEqual(commands[0]['argv'][-1], '0.1.25')

    def test_termux_machine_fabric_install_uses_android_release(self):
        c = self.context('termux')
        c.env.update(MACHINE_FABRIC_VERSION='0.1.33',
                     MACHINE_FABRIC_RELEASE_BASE_URL='https://example.invalid/fabric')
        c.task('setup_machine_fabric')
        downloads = [event for event in c.events if event['kind'] == 'download']
        commands = [event for event in c.events if event['kind'] == 'command']
        self.assertEqual(len(downloads), 1)
        self.assertIn('machine-fabric/main/scripts/install-from-release.sh', downloads[0]['url'])
        self.assertEqual(commands[0]['argv'][-1], '0.1.33')

    def test_windows_plan_contains_real_package_sets_and_no_unix_installer(self):
        c = self.context('windows')
        for name, args in select_tasks('windows', 'all', []):
            c.task(name, *args)
        argv = [e['argv'] for e in c.events if e['kind'] == 'command']
        flattened = [value for command in argv for value in command]
        for group, sets in PACKAGES.items():
            if group.startswith('windows/prepare_windows_env_'):
                for lists in sets.values():
                    for values in lists:
                        for value in values:
                            self.assertIn(value, flattened)
        self.assertFalse(any(cmd[0] in ('bash', 'sh', 'apt', 'brew') for cmd in argv))

    def test_no_legacy_bootstrap_dispatch(self):
        self.assertEqual(list((ROOT / 'bootstrap').glob('*.sh')), [])
        self.assertEqual(list((ROOT / 'bootstrap').glob('*.ps1')), [])
        for platform in PLATFORMS:
            c = self.context(platform)
            for name, args in select_tasks(platform, 'all', []):
                c.task(name, *args)
            for event in c.events:
                if event['kind'] == 'command':
                    for value in event['argv']:
                        self.assertNotIn(str(ROOT / 'bootstrap') + os.sep, value)

    def test_report_captures_native_streams_and_nested_failures(self):
        terminal = io.StringIO()
        reporter = Reporter(self.home / 'state', 'test', stream=terminal)
        c = self.context(dry=False, reporter=reporter)
        c.tasks['child'] = lambda ctx: ctx.command(sys.executable, '-c',
            "import sys; print('RAW_OUT'); print('RAW_ERR', file=sys.stderr); sys.exit(7)")
        c.tasks['parent'] = lambda ctx: ctx.task('child')
        with redirect_stdout(reporter.log), redirect_stderr(reporter.log):
            with self.assertRaisesRegex(Failure, 'status 7'):
                c.task('parent')
        reporter.close()
        self.assertNotIn('RAW_OUT', terminal.getvalue())
        self.assertNotIn('RAW_ERR', terminal.getvalue())
        self.assertIn('FAIL parent', terminal.getvalue())
        self.assertNotIn('OK   child', terminal.getvalue())
        self.assertIn('RAW_OUT', reporter.log_path.read_text(encoding='utf-8'))
        self.assertIn('RAW_ERR', reporter.log_path.read_text(encoding='utf-8'))
        rows = json.loads((reporter.directory / 'results.json').read_text(encoding='utf-8'))
        self.assertEqual(rows['status'], 'FAILED')
        self.assertEqual([r['status'] for r in rows['tasks']], ['FAIL', 'FAIL'])

    def test_stderr_alone_is_not_failure_on_any_platform(self):
        reporter = Reporter(self.home / 'state', 'stderr', stream=io.StringIO())
        c = self.context(dry=False, reporter=reporter)
        try:
            self.assertEqual(c.command(sys.executable, '-c', "import sys; sys.stderr.write('diagnostic\\n')"), 0)
        finally:
            reporter.close()

    def test_argv_is_data_not_shell_code(self):
        reporter = Reporter(self.home / 'state', 'argv', stream=io.StringIO())
        c = self.context(dry=False, reporter=reporter)
        try:
            value = 'spaces & semicolon; quote" backtick` $HOME $(not-a-command)'
            result = c.command(sys.executable, '-c', 'import sys; print(sys.argv[1])', value, capture=True)
            self.assertEqual(result.strip(), value)
            self.assertIn(value, reporter.log_path.read_text(encoding='utf-8'))
        finally:
            reporter.close()

    def test_process_environment_survives_steps(self):
        reporter = Reporter(self.home / 'state', 'environment', stream=io.StringIO())
        c = self.context(dry=False, reporter=reporter)
        c.tasks['set_value'] = lambda ctx: ctx.env.update(DOTFILES_TEST_VALUE='retained')
        try:
            c.task('set_value')
            result = c.command(sys.executable, '-c', "import os; print(os.environ['DOTFILES_TEST_VALUE'])", capture=True)
            self.assertEqual(result.strip(), 'retained')
        finally:
            reporter.close()

    def test_running_homebrew_python_is_protected_from_cleanup(self):
        self.env['HOMEBREW_NO_CLEANUP_FORMULAE'] = 'node'
        for suffix in ('', '/Frameworks/Python.framework/Versions/3.14'):
            prefix = self.home / ('brew/Cellar/python@3.14/3.14.6' + suffix)
            with self.subTest(suffix=suffix), patch('sys.base_prefix', str(prefix)):
                c = self.context(dry=False)
                self.assertEqual(c.env['HOMEBREW_NO_CLEANUP_FORMULAE'], 'node,python@3.14')
                value = c.command(sys.executable, '-c',
                    "import os; print(os.environ['HOMEBREW_NO_CLEANUP_FORMULAE'])", capture=True)
                self.assertEqual(value.strip(), 'node,python@3.14')
        self.assertEqual(self.env['HOMEBREW_NO_CLEANUP_FORMULAE'], 'node')
        with patch('sys.base_prefix', str(self.home / 'system-python')):
            self.assertEqual(self.context().env['HOMEBREW_NO_CLEANUP_FORMULAE'], 'node')

    def test_rust_setup_installs_only_when_toolchain_is_missing(self):
        for exists, status in ((False, 0), (True, 1), (True, 0)):
            with self.subTest(exists=exists, status=status):
                c = self.context()
                with patch.object(c, 'exists', return_value=exists), \
                     patch.object(c, 'command', return_value=status), \
                     patch.object(c, 'installer') as installer:
                    c.task('rustup_setup')
                self.assertEqual(installer.called, not exists or status != 0)

    def test_anyenv_initializes_only_missing_manifests(self):
        for custom in (False, True):
            manifest = self.home / ('custom-manifest' if custom else 'config/anyenv/anyenv-install')
            if custom:
                self.env['ANYENV_DEFINITION_ROOT'] = str(manifest)
            for exists in (False, True):
                with self.subTest(custom=custom, exists=exists):
                    if exists:
                        manifest.mkdir(parents=True)
                    c = self.context()
                    c.task('anyenv_setup')
                    commands = [e['argv'] for e in c.events if e['kind'] == 'command']
                    self.assertEqual(any('--force-init' in cmd for cmd in commands), not exists)
                    self.assertIn(['anyenv', 'install', '--skip-existing', 'pyenv'], commands)

    def test_windows_sync_applies_links_in_isolated_home_without_commands(self):
        repo = self.home / 'source-repo'
        config = repo / 'config'
        (config / 'sh').mkdir(parents=True)
        shutil.copy2(ROOT / 'config/sh/xdg-ninja-patch.sh', config / 'sh/xdg-ninja-patch.sh')
        (repo / 'util/git/hooks').mkdir(parents=True)
        c = Context(repo, 'windows', home=self.home, env=self.env)
        c.tasks = TASKS
        for source, _ in LINKS['windows/set_windows_configs']:
            path = c.path(source)
            path.parent.mkdir(parents=True, exist_ok=True)
            if source == '$config_dir/Rime':
                path.mkdir()
                (path / 'lfs-manifest.json').write_text('[]\n')
            else:
                path.write_text('sample configuration', encoding='utf-8')
        with patch('subprocess.Popen', side_effect=AssertionError('sync spawned a command')):
            try:
                c.task('sync_setup')
            except OSError as exc:
                if os.name == 'nt' and getattr(exc, 'winerror', None) == 1314:
                    self.skipTest('Windows session lacks symlink privilege')
                raise
            c.task('sync_setup')
        links = [e for e in c.events if e['kind'] == 'link']
        self.assertEqual(len(links), 12)
        for entry in links:
            target = Path(entry['target'])
            self.assertTrue(target.is_relative_to(self.home))
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), Path(entry['source']))
        self.assertTrue((c.config / 'tig').is_symlink())
        self.assertTrue((self.home / '.ssh/config').is_file())
        self.assertFalse((self.home / '.ssh/config').is_symlink())

    def test_ssh_migrates_shared_link_and_preserves_later_injections(self):
        c = self.context(dry=False)
        dest = self.home / '.ssh/config'
        shared = ROOT / 'config/ssh/config'
        original = shared.read_bytes()
        dest.parent.mkdir()
        try:
            dest.symlink_to(shared)
        except OSError as exc:
            if os.name == 'nt' and getattr(exc, 'winerror', None) == 1314:
                self.skipTest('Windows session lacks symlink privilege')
            raise
        local = dest.with_name('config.local')
        local.write_text('Host private\n  User teammate\n', encoding='utf-8')
        c.task('ssh_setup')
        self.assertFalse(dest.is_symlink())
        self.assertTrue(dest.with_name('config~').is_symlink())
        self.assertIn(shared.as_posix(), dest.read_text())
        self.assertFalse(local.exists())
        self.assertEqual(local.with_name('config.local~').read_text(), 'Host private\n  User teammate\n')
        self.assertIn('Host private\n  User teammate\n', dest.read_text())
        injection = '# -- CloudIDE injection begin --\nInclude "cloudide/*"\n# -- CloudIDE injection end --\n'
        dest.write_text(injection + dest.read_text(), encoding='utf-8')
        before = dest.read_bytes()
        files = sorted(p.name for p in dest.parent.iterdir())
        c.task('ssh_setup')
        self.assertEqual(dest.read_bytes(), before)
        self.assertEqual(shared.read_bytes(), original)
        self.assertEqual(sorted(p.name for p in dest.parent.iterdir()), files)
        if os.name != 'nt':
            self.assertEqual(dest.stat().st_mode & 0o777, 0o600)

    def test_ssh_preserves_existing_config_and_dry_run_has_no_effects(self):
        dest = self.home / '.ssh/config'
        dest.parent.mkdir()
        original = 'Host existing\n  HostName existing.example\n  User custom'
        dest.write_text(original, encoding='utf-8')
        self.context(dry=True).task('ssh_setup')
        self.assertEqual(dest.read_text(), original)
        self.assertEqual(list(dest.parent.iterdir()), [dest])
        c = self.context(dry=False)
        c.task('ssh_setup')
        self.assertTrue(dest.read_text().startswith(original + '\n'))
        self.assertEqual(dest.with_name('config~').read_text(), original)
        c.task('ssh_setup')
        self.assertEqual(dest.read_text().count('# -- dotfiles SSH config begin --'), 1)

    def test_ssh_merges_old_local_include_and_keeps_shared_defaults_last(self):
        c = self.context(dry=False)
        dest = self.home / '.ssh/config'
        dest.parent.mkdir()
        local = dest.with_name('config.local')
        local.write_text('Host private\n  User teammate\n', encoding='utf-8')
        original = ('# tool prefix\nHost before\n  User before\n'
                    '# -- dotfiles SSH config begin --\nHost *\n'
                    f'  Include "{local.as_posix()}"\nHost *\n'
                    f'  Include "{(ROOT / "config/ssh/config").as_posix()}"\nHost *\n'
                    '# -- dotfiles SSH config end --\n'
                    '# tool suffix\nHost after\n  User after\n')
        dest.write_text(original, encoding='utf-8')
        self.context(dry=True).task('ssh_setup')
        self.assertEqual(dest.read_text(), original)
        self.assertTrue(local.exists())
        c.task('ssh_setup')
        merged = dest.read_text()
        self.assertNotIn('Include "' + local.as_posix() + '"', merged)
        self.assertIn('Host before\n  User before\nHost *\n# tool suffix', merged)
        self.assertLess(merged.index('Host after'), merged.index('# -- dotfiles SSH config begin --'))
        self.assertLess(merged.index('Host private'), merged.index('# -- dotfiles SSH config begin --'))
        self.assertTrue(merged.endswith('  Include "' + (ROOT / 'config/ssh/config').as_posix()
                                        + '"\n# -- dotfiles SSH config end --\n'))
        self.assertFalse(local.exists())
        c.task('ssh_setup')
        self.assertEqual(dest.read_text(), merged)
        self.assertFalse(local.exists())

    @unittest.skipUnless(shutil.which('ssh'), 'OpenSSH configuration parser')
    def test_ssh_local_overrides_and_include_scope_with_spaces(self):
        c = self.context(dry=False)
        c.repo = self.home / 'repo with spaces'
        shared = c.repo / 'config/ssh/config'
        shared.parent.mkdir(parents=True)
        shared.write_text('Host *\n  ServerAliveInterval 30\nHost shared.example\n  User shared\n', encoding='utf-8')
        local = self.home / '.ssh/config.local'
        local.parent.mkdir()
        local.write_text('Host override.example\n  ServerAliveInterval 71\nHost unmatched.example\n  User other\n', encoding='utf-8')
        c.task('ssh_setup')
        dest = local.with_name('config')
        for host, expected in [('override.example', 'serveraliveinterval 71'),
                               ('shared.example', 'user shared')]:
            try:
                result = subprocess.run(['ssh', '-G', '-F', str(dest), host],
                                        capture_output=True, text=True, timeout=10)
            except subprocess.TimeoutExpired:
                if os.name == 'nt':
                    self.skipTest('Windows OpenSSH -G hangs in a headless session')
                raise
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(expected, result.stdout)

    @unittest.skipIf(os.name == 'nt', 'Unix sudo authentication')
    def test_sudo_authenticates_visibly_before_captured_commands(self):
        c = self.context(dry=False)
        with patch('sys.stdin.isatty', return_value=True), \
             patch.object(c, '_command', side_effect=[1, 0, 0]) as execute:
            c.command('sudo', 'install', 'source', 'target')
        calls = execute.call_args_list
        self.assertEqual(calls[0].args[0], ['sudo', '-n', '-v'])
        self.assertEqual(calls[1].args[0], ['sudo', '-v'])
        self.assertTrue(calls[1].kwargs['interactive'])
        self.assertEqual(calls[2].args[0], ['sudo', 'install', 'source', 'target'])

    @unittest.skipIf(os.name == 'nt', 'POSIX process sessions')
    def test_captured_sudo_preserves_authentication_session(self):
        c = self.context(dry=False)
        probe = 'import os; print(os.getsid(0))'
        # Use Python as a harmless stand-in; never invoke real sudo in tests.
        with patch('dotfiles.engine.shutil.which', return_value=sys.executable):
            for command in ('sudo', '/usr/bin/sudo'):
                session = c._command([command, '-c', probe], capture=True)
                self.assertEqual(int(session), os.getsid(0))
            session = c._command([sys.executable, '-c', probe], capture=True)
            self.assertNotEqual(int(session), os.getsid(0))

    def test_macos_preference_paths_are_expanded_as_data(self):
        c = self.context('macos')
        c.task('better_macos_defaults')
        argv = [e['argv'] for e in c.events if e['kind'] == 'command']
        self.assertTrue(any(Path(item) == c.home / 'Desktop' for row in argv for item in row))
        self.assertFalse(any('${HOME}' in item or item.startswith('~/') for row in argv for item in row))

    def test_rejected_macos_preference_does_not_skip_remaining_setup(self):
        c = self.context('macos', dry=False)
        def run(*argv, **kwargs):
            return int(argv[:3] == ('defaults', 'write', 'com.apple.universalaccess'))
        with patch.object(c, 'command', side_effect=run) as execute:
            c.task('better_macos_defaults')
        self.assertTrue(any(e['kind'] == 'note' and 'Preference not applied:' in e['text']
                            for e in c.events))
        self.assertTrue(any(call.args[:3] == ('defaults', 'write', 'com.apple.finder')
                            for call in execute.call_args_list))
        self.assertTrue(any(call.args == ('killall', 'SystemUIServer')
                            for call in execute.call_args_list))
        with patch.object(c, 'command', side_effect=Failure('required setup failed')):
            with self.assertRaisesRegex(Failure, 'required setup failed'):
                c.task('better_macos_defaults')

    def test_existing_files_are_backed_up_and_symlinks_are_idempotent(self):
        c = self.context(dry=False)
        source = self.home / 'source'
        source.write_text('source')
        target = self.home / 'target'
        target.write_text('original')
        Path(str(target) + '~').write_text('older backup')
        try:
            c.link(source, target)
        except OSError as exc:
            if os.name == 'nt' and getattr(exc, 'winerror', None) == 1314:
                self.skipTest('Windows session lacks symlink privilege')
            raise
        self.assertTrue(target.is_symlink())
        self.assertEqual(Path(str(target) + '~').read_text(encoding='utf-8'), 'older backup')
        backups = list(self.home.glob('target.backup-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(encoding='utf-8'), 'original')
        c.link(source, target)
        self.assertEqual(len(list(self.home.glob('target.backup-*'))), 1)

    def test_write_is_atomic_and_xdg_state_is_honored(self):
        c = self.context(dry=False)
        target = c.state / 'nested/file'
        c.write(target, 'one')
        c.write(target, 'two')
        self.assertEqual(target.read_text(encoding='utf-8'), 'two')
        self.assertEqual(list(target.parent.iterdir()), [target])
        self.assertEqual(c.state, self.home / 'state')
        if os.name != 'nt':
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)

    def test_binary_command_output_is_atomic_and_failures_preserve_destination(self):
        c = self.context(dry=False)
        # Child runtimes may create caches in HOME (e.g. Apple's Python).
        # Atomic output must leave no temporary files beside the destination.
        target = self.home / 'output' / 'artifact'
        c.command(sys.executable, '-c', "import sys; sys.stdout.buffer.write(bytes([0, 255, 10]))", output_file=target)
        self.assertEqual(target.read_bytes(), bytes([0, 255, 10]))
        with self.assertRaises(Failure):
            c.command(sys.executable, '-c', "import sys; print('partial'); sys.exit(3)", output_file=target)
        self.assertEqual(target.read_bytes(), bytes([0, 255, 10]))
        self.assertEqual(list(target.parent.iterdir()), [target])

    def test_tty_updates_current_step_then_collapses_category(self):
        terminal = io.StringIO()
        reporter = Reporter(self.home / 'state', 'TTY', stream=terminal)
        # Simulate a VT-capable terminal even in CI/SSH without a console handle.
        reporter.tty = True
        reporter.thread.start()
        self.addCleanup(reporter.close)
        with reporter.task('Packages'):
            with reporter.task('Python tools'):
                with reporter.operation('uv tool install example'):
                    deadline = time.monotonic() + 3
                    while 'uv tool install example' not in terminal.getvalue() and time.monotonic() < deadline:
                        time.sleep(.02)
        reporter.close()
        output = terminal.getvalue()
        self.assertIn('\r\033[2K', output)
        self.assertIn('Packages / Python tools / uv tool install example', output)
        self.assertNotIn('OK   Python tools', output)
        self.assertIn('DONE | 1 categories', output)
        self.assertEqual(output.count('OK   Packages'), 2)  # completed line and final summary

    @unittest.skipIf(os.name == 'nt', 'POSIX launcher')
    def test_posix_launcher_forwards_plan_arguments_and_exit_status(self):
        result = subprocess.run([str(ROOT / 'init'), '--dry-run', '--json', '--platform', 'windows', 'core'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['platform'], 'windows')
        invalid = subprocess.run([str(ROOT / 'init'), 'bad-mode'], capture_output=True)
        self.assertEqual(invalid.returncode, 2)

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS runtime discovery')
    def test_macos_launcher_finds_homebrew_python_with_minimal_path(self):
        if not any(Path(p).exists() for p in ('/opt/homebrew/bin/python3', '/usr/local/bin/python3')):
            self.skipTest('Homebrew Python is not installed')
        env = dict(os.environ, PATH='/usr/bin:/bin:/usr/sbin:/sbin')
        env.pop('LANG', None)
        result = subprocess.run([str(ROOT / 'init'), 'core', '--dry-run', '--json'],
                                env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['platform'], 'macos')

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS native preference tools')
    def test_macos_native_tools_write_only_private_plist(self):
        reporter = Reporter(self.home / 'state', 'macOS plist', stream=io.StringIO())
        c = self.context('macos', dry=False, reporter=reporter)
        domain = self.home / 'test preferences'
        value = 'spaces & quotes " and $HOME stay literal'
        try:
            c.command('/usr/bin/defaults', 'write', domain, 'sample', '-string', value)
            result = c.command('/usr/bin/defaults', 'read', domain, 'sample', capture=True)
            self.assertEqual(result.strip(), value)
            plist = Path(str(domain) + '.plist')
            c.command('/usr/libexec/PlistBuddy', '-c', 'Add :enabled bool true', plist)
            import plistlib
            with plist.open('rb') as stream:
                saved = plistlib.load(stream)
            self.assertEqual(saved['sample'], value)
            self.assertIs(saved['enabled'], True)
        finally:
            reporter.close()

    @unittest.skipUnless(sys.platform == 'darwin', 'macOS configuration links')
    def test_macos_configuration_links_are_idempotent_in_private_home(self):
        c = self.context('macos', dry=False)
        repo = self.home / 'source-repo'
        repo.mkdir()
        c.repo = repo.resolve()
        c.variables.update(repo_path=str(c.repo), config_dir=str(c.repo / 'config'), util_dir=str(c.repo / 'util'))
        groups = ('nix/apply_nix_app_configs', 'macos/set_macos_configs')
        from dotfiles.tasks import links
        for group in groups:
            for source, _ in LINKS[group]:
                path = c.path(source)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.mkdir(exist_ok=True)
        (c.repo / 'config/Rime/lfs-manifest.json').write_text('[]\n')
        for _ in range(2):
            for group in groups:
                links(c, group)
        for event in c.events:
            if event['kind'] == 'link':
                target = Path(event['target'])
                self.assertTrue(target.is_relative_to(self.home))
                self.assertTrue(target.is_symlink())
                self.assertEqual(target.resolve(), Path(event['source']).resolve())

    def test_migration_retargets_links_and_can_be_repeated(self):
        legacy = self.home / '.dotfiles'
        legacy.mkdir()
        (legacy / 'sample').write_text('configuration')
        link = self.home / '.sample'
        try:
            link.symlink_to(legacy / 'sample')
        except OSError as exc:
            if os.name == 'nt' and getattr(exc, 'winerror', None) == 1314:
                self.skipTest('Windows session lacks symlink privilege')
            raise
        c = self.context(dry=False)
        c.repo = legacy.resolve()
        c.task('migrate_xdg')
        target = c.config / 'dotfiles'
        self.assertFalse(legacy.exists())
        self.assertEqual(link.resolve(), (target / 'sample').resolve())
        self.assertEqual(link.read_text(encoding='utf-8'), 'configuration')
        c.repo = target.resolve()
        c.task('migrate_xdg')
        self.assertFalse(legacy.exists())

    @unittest.skipUnless(os.name == 'nt', 'PowerShell launchers')
    def test_powershell_5_and_7_launchers_forward_plan_and_failure(self):
        for name in ('powershell.exe', 'pwsh.exe'):
            executable = shutil.which(name)
            if not executable:
                continue
            with self.subTest(shell=name):
                prefix = [executable, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(ROOT / 'init.ps1')]
                result = subprocess.run([*prefix, '--dry-run', '--json', '--platform', 'windows', 'core'],
                                        capture_output=True, encoding='utf-8', errors='replace')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout)['platform'], 'windows')
                invalid = subprocess.run([*prefix, 'bad-mode'], capture_output=True)
                self.assertEqual(invalid.returncode, 2)

    def test_cross_platform_override_cannot_apply(self):
        with self.assertRaises(SystemExit), redirect_stderr(io.StringIO()):
            main(['core', '--platform', 'windows'])

    def test_named_run_accepts_arguments_and_rejects_shell_eval(self):
        self.assertEqual(select_tasks('macos', 'run', ['macos', 'backup_automator_stuff']), [('backup_automator_stuff', [])])
        self.assertEqual(select_tasks('debian', 'run', ['pkg', 'install_npm_packages core']), [('install_npm_packages', ['core'])])
        with self.assertRaises(Failure):
            select_tasks('debian', 'run', ['env', 'echo unsafe; true'])

    @unittest.skipUnless(os.name == 'nt', 'Windows process adapter')
    def test_windows_cmd_shim_preserves_argv_and_exit_code(self):
        shim = self.home / 'test shim.cmd'
        shim.write_text('@echo off\necho %~1\nexit /b 9\n')
        reporter = Reporter(self.home / 'state', 'shim', stream=io.StringIO())
        c = self.context('windows', dry=False, reporter=reporter)
        try:
            with self.assertRaisesRegex(Failure, 'status 9'):
                c.command(shim, 'two words')
        finally:
            reporter.close()
        self.assertIn('two words', reporter.log_path.read_text(encoding='utf-8'))

    @unittest.skipUnless(os.name == 'nt', 'Windows process adapter')
    def test_windows_ps1_shim_preserves_native_failure(self):
        shim = self.home / 'native.ps1'
        shim.write_text('cmd.exe /d /c exit 7\n')
        reporter = Reporter(self.home / 'state', 'shim', stream=io.StringIO())
        c = self.context('windows', dry=False, reporter=reporter)
        try:
            with self.assertRaisesRegex(Failure, 'status 7'):
                c.command(shim)
        finally:
            reporter.close()

    @unittest.skipUnless(os.name == 'nt', 'Windows PowerShell 5 process adapter')
    def test_windows_legacy_powershell_adapter_streams_and_errors(self):
        shim = self.home / 'legacy.ps1'
        reporter = Reporter(self.home / 'state', 'legacy', stream=io.StringIO())
        c = self.context('windows', dry=False, reporter=reporter)
        installed = c.exists
        c.exists = lambda name: name != 'pwsh.exe' and installed(name)
        try:
            shim.write_text('cmd.exe /d /c "echo diagnostic 1>&2"\n', encoding='utf-8')
            self.assertEqual(c.command(shim), 0)
            shim.write_text('cmd.exe /d /c exit 7\n', encoding='utf-8')
            with self.assertRaisesRegex(Failure, 'status 7'):
                c.command(shim)
            shim.write_text("Write-Error 'intentional error'\n", encoding='utf-8')
            with self.assertRaises(Failure):
                c.command(shim)
        finally:
            reporter.close()
        self.assertIn('diagnostic', reporter.log_path.read_text(encoding='utf-8'))

    @unittest.skipUnless(os.name == 'nt', 'Windows runtime preflight')
    def test_windows_scoop_preflight_checks_native_exit_not_stderr(self):
        source = (ROOT / 'init.ps1').read_text(encoding='utf-8')
        helper = source[source.index('function Invoke-Scoop {'):source.index('\nfunction Get-ScoopPython')]
        script = "$ErrorActionPreference='Stop'\n" + helper + "\n"
        script += '''Invoke-Scoop 'cmd.exe' @('/d', '/c', 'echo diagnostic 1>&2')
try {
  Invoke-Scoop 'cmd.exe' @('/d', '/c', 'exit 7')
  exit 1
} catch {
  if ($_.Exception.Message -match 'status 7') { exit 0 }
  throw
}
'''
        encoded = base64.b64encode(script.encode('utf-16le')).decode()
        result = subprocess.run(['powershell.exe', '-NoProfile', '-EncodedCommand', encoded], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
