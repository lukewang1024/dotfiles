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
from dotfiles.engine import Context, Failure, Reporter
from dotfiles.tasks import TASKS, PACKAGES, LINKS, language_packages


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
        after = sorted(str(p.relative_to(self.home)) for p in self.home.rglob('*'))
        self.assertEqual(before, after)

    def test_package_and_link_data_preserve_legacy_inventory(self):
        legacy = json.loads((ROOT / 'tests/fixtures/bootstrap-inventory.json').read_text(encoding='utf-8'))
        self.assertEqual(PACKAGES, {k: v['arrays'] for k, v in legacy.items() if v['arrays']})
        self.assertEqual(LINKS, {k: v['links'] for k, v in legacy.items() if v['links']})

    def test_package_selection_does_not_mutate_catalog(self):
        before = json.dumps(PACKAGES, sort_keys=True)
        c = self.context()
        a = language_packages(c, 'install_gem_packages', 'all')
        b = language_packages(c, 'install_gem_packages', 'all')
        self.assertEqual(a, b)
        self.assertEqual(before, json.dumps(PACKAGES, sort_keys=True))

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
        self.assertEqual(len(links), 14)
        for entry in links:
            target = Path(entry['target'])
            self.assertTrue(target.is_relative_to(self.home))
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), Path(entry['source']))
        self.assertTrue((c.config / 'tig').is_symlink())

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
        target = self.home / 'artifact'
        c.command(sys.executable, '-c', "import sys; sys.stdout.buffer.write(bytes([0, 255, 10]))", output_file=target)
        self.assertEqual(target.read_bytes(), bytes([0, 255, 10]))
        with self.assertRaises(Failure):
            c.command(sys.executable, '-c', "import sys; print('partial'); sys.exit(3)", output_file=target)
        self.assertEqual(target.read_bytes(), bytes([0, 255, 10]))
        self.assertEqual(list(self.home.iterdir()), [target])

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
    def test_windows_runtime_preflight_checks_native_exit_not_stderr(self):
        source = (ROOT / 'init.ps1').read_text(encoding='utf-8')
        helper = source[source.index('function Invoke-RuntimeCommand {'):source.index('\ntry {')]
        log = self.home / 'runtime.log'
        script = "$ErrorActionPreference='Stop'; $runtimeLog='" + str(log).replace("'", "''") + "'\n" + helper + "\n"
        script += '''Invoke-RuntimeCommand 'cmd.exe' @('/d', '/c', 'echo diagnostic 1>&2')
try {
  Invoke-RuntimeCommand 'cmd.exe' @('/d', '/c', 'exit 7')
  exit 1
} catch {
  if ($_.Exception.Message -match 'exit code 7') { exit 0 }
  throw
}
'''
        encoded = base64.b64encode(script.encode('utf-16le')).decode()
        result = subprocess.run(['powershell.exe', '-NoProfile', '-EncodedCommand', encoded], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(log.exists())


if __name__ == '__main__':
    unittest.main()
