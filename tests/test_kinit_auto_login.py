"""Exercise iSH auto-login with fake credentials and no network access."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'util/kerberos/kinit-auto-login'
SH = shutil.which('sh')


@unittest.skipUnless(os.name == 'posix' and SH, 'POSIX shell required')
class KinitAutoLoginTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / 'config'
        self.data = self.root / 'data with spaces'
        self.state = self.root / 'state'
        self.cache = self.root / 'cache'
        self.tools = self.root / 'tools'
        self.tools.mkdir()
        self.calls = self.root / 'kinit-calls'
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(('XDG_', 'KRB', 'KINIT_', 'KAL_', 'ISH_'))}
        self.env.update(HOME=str(self.root), XDG_CONFIG_HOME=str(self.config),
                        XDG_DATA_HOME=str(self.data), XDG_STATE_HOME=str(self.state),
                        XDG_CACHE_HOME=str(self.cache), SHELL='/bin/zsh',
                        ZDOTDIR=str(self.config / 'zsh'), KINIT_SUPERVISOR='nohup',
                        KAL_TEST_CALLS=str(self.calls),
                        PATH=str(self.tools) + os.pathsep + os.environ['PATH'])
        self.write_tool('uname', '#!/bin/sh\ncase $1 in -r) echo "${KAL_TEST_RELEASE:-4.20.69-ish}" ;; *) echo Linux ;; esac\n')
        self.write_tool('kinit', '#!/bin/sh\n{ printf "%s\\n" "${KRB5_CONFIG:-unset}" "${KRB5CCNAME:-unset}" "$@"; } >> "$KAL_TEST_CALLS"\nexit "${KAL_TEST_FAILURE:-0}"\n')
        self.write_tool('klist', '#!/bin/sh\nexit 1\n')
        profile = self.config / 'ish-kerberos'
        profile.mkdir(parents=True)
        (profile / 'user.conf').write_text('KRB5_REALM=ISH.TEST\nKRB5_PRINCIPAL=tester@ISH.TEST\n')
        (profile / 'krb5.conf').write_text('# test profile\n')
        self.keytab = self.data / 'kinit-auto-login/tester.keytab'
        self.keytab.parent.mkdir(parents=True)
        self.keytab.write_bytes(b'fake keytab; never used with real kinit')
        self.addCleanup(self.stop_daemon)

    def write_tool(self, name, source):
        path = self.tools / name
        path.write_text(source)
        path.chmod(0o755)

    def run_helper(self, *arguments):
        return subprocess.run([SH, str(SCRIPT), *arguments], env=self.env,
                              capture_output=True, text=True, timeout=20)

    def stop_daemon(self):
        pid_file = self.state / 'kinit-auto-login/kinit-daemon.pid'
        if pid_file.exists():
            result = self.run_helper('uninstall')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(pid_file.exists())

    def test_nonlogin_renew_uses_ish_profile_and_shared_ticket_cache(self):
        result = self.run_helper('renew')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls.read_text().splitlines(), [
            str(self.config / 'ish-kerberos/krb5.conf'),
            'FILE:' + str(self.cache / 'ish-kerberos/krb5cc'),
            '-kt', str(self.keytab), 'tester@ISH.TEST'])
        self.assertTrue((self.cache / 'ish-kerberos').is_dir())
        self.assertFalse((self.cache / 'ish-kerberos/krb5cc').exists())
        self.assertTrue((self.state / 'kinit-auto-login/kinit.log').is_file())

    def test_explicit_principal_cache_and_keytab_are_preserved(self):
        conf = self.config / 'kinit-auto-login'
        conf.mkdir()
        (conf / 'kinit.env').write_text('KRB_PRINCIPAL=old@ISH.TEST\nKEYTAB_PATH=' +
                                       shlex.quote(str(self.keytab)) + '\n')
        self.env['KRB5_CONFIG'] = str(self.root / 'administrator.conf')
        self.env['KRB5CCNAME'] = 'FILE:' + str(self.root / 'custom-cache/ticket')
        result = self.run_helper('renew', '--principal', 'chosen@ISH.TEST')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls.read_text().splitlines(), [
            self.env['KRB5_CONFIG'], self.env['KRB5CCNAME'],
            '-kt', str(self.keytab), 'chosen@ISH.TEST'])

    def test_install_is_idempotent_and_keeps_repository_zshrc_untouched(self):
        shared = self.root / 'shared.zshrc'
        shared.write_text('# tracked shell configuration\n')
        zdotdir = self.config / 'zsh'
        zdotdir.mkdir()
        (zdotdir / '.zshrc').symlink_to(shared)
        local = self.config / '.zshrc.local'
        local.write_text('# keep local overrides\n')
        result = self.run_helper('install')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        pid_file = self.state / 'kinit-auto-login/kinit-daemon.pid'
        first_pid = pid_file.read_text()
        first_hook = local.read_text()
        self.assertTrue(first_hook.startswith('# keep local overrides\n'))
        self.assertEqual(first_hook.count('# >>> dotfiles kinit-auto-login (managed) >>>'), 1)
        self.assertEqual(shared.read_text(), '# tracked shell configuration\n')
        self.assertEqual((self.config / 'kinit-auto-login/kinit.env').stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.state / 'kinit-auto-login').stat().st_mode & 0o777, 0o700)
        again = self.run_helper('install')
        self.assertEqual(again.returncode, 0, again.stdout + again.stderr)
        self.assertEqual(pid_file.read_text(), first_pid)
        self.assertEqual(local.read_text(), first_hook)
        status = self.run_helper('status')
        self.assertEqual(status.returncode, 0, status.stderr)
        self.assertIn('nohup daemon running', status.stdout)
        # Both the initial check and the background renewal use the iSH cache.
        self.assertGreaterEqual(self.calls.read_text().count('FILE:' + str(self.cache / 'ish-kerberos/krb5cc')), 2)
        self.stop_daemon()
        self.assertEqual(local.read_text(), '# keep local overrides\n\n')

    def test_keytab_generation_uses_installed_ish_python_wrapper(self):
        binary = self.root / '.local/bin'
        binary.mkdir(parents=True)
        wrapper = binary / 'python3'
        wrapper.write_text('#!/bin/sh\ncat >/dev/null\nprintf "%s\\n" "$KAL_PRINCIPAL" > "$KAL_TEST_CALLS"\n')
        wrapper.chmod(0o755)
        self.write_tool('python3', '#!/bin/sh\nexit 99\n')
        result = self.run_helper('gen-keytab')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls.read_text().strip(), 'tester@ISH.TEST')

    def test_invalid_keytab_does_not_install_autostart_or_daemon(self):
        self.env['KAL_TEST_FAILURE'] = '1'
        result = self.run_helper('install')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.config / '.zshrc.local').exists())
        self.assertFalse((self.state / 'kinit-auto-login/kinit-daemon.pid').exists())

    def test_other_linux_keeps_existing_keytab_and_cache_behavior(self):
        self.env['KAL_TEST_RELEASE'] = '6.1.0'
        conf = self.config / 'kinit-auto-login'
        conf.mkdir()
        keytab = conf / 'krb5/legacy.keytab'
        keytab.parent.mkdir()
        keytab.touch()
        (conf / 'kinit.env').write_text('KRB_PRINCIPAL=legacy@ISH.TEST\n')
        result = self.run_helper('renew')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls.read_text().splitlines(), [
            'unset', 'unset', '-kt', str(keytab), 'legacy@ISH.TEST'])
