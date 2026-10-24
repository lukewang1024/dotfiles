"""Connection policy and interactive ticket recovery; no external hosts/secrets."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'util/shell/ssh-connect'
SAFE_POLICY = '''gssapiauthentication yes
gssapidelegatecredentials no
preferredauthentications gssapi-with-mic
passwordauthentication no
kbdinteractiveauthentication no
hostbasedauthentication no
pubkeyauthentication false
controlmaster false
stricthostkeychecking ask
'''


@unittest.skipUnless(os.name == 'posix' and shutil.which('sh'), 'POSIX shell required')
class SSHConnectTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.conf = self.home / 'config'
        (self.conf / 'ssh').mkdir(parents=True)
        self.hosts = self.conf / 'ssh/hosts'
        self.hosts.write_text('devbox\nordinary\n')
        self.mapping = self.conf / 'ssh/kerberos'
        self.mapping.write_text('devbox testuser@ISH.TEST dev\n')
        self.log = self.home / 'calls'
        self.state = self.home / 'ticket'
        self.state.write_text('testuser@ISH.TEST')
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.conf),
                        XDG_CACHE_HOME=str(self.home / 'cache'), PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        TEST_HOME=str(self.home), TEST_POLICY=SAFE_POLICY)
        for name in ('ISH_CONFIG_DIR', 'SSH_CONNECT_HOSTS_FILE', 'SSH_CONNECT_SSH_DIR',
                     'SSH_CONNECT_KERBEROS_FILE', 'KRB5_CONFIG', 'KRB5CCNAME'):
            self.env.pop(name, None)
        self.env.update(KRB5_CONFIG='/termux/etc/krb5.conf', KRB5CCNAME='FILE:/termux/cache/ticket')
        helper = self.bin / 'stub'
        helper.write_text(f'#!{sys.executable}\n' + '''
import json, os, pathlib, sys
h = pathlib.Path(os.environ['TEST_HOME'])
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with (h/'calls').open('a') as out:
    out.write(json.dumps([name, args, os.environ.get('KRB5_CONFIG'), os.environ.get('KRB5CCNAME')])+'\\n')
if name == 'klist':
    if not (h/'ticket').exists(): sys.exit(1)
    principal = (h/'ticket').read_text()
    if principal in ('expired', 'corrupt'): sys.exit(1)
    if args != ['-s']:
        print('Default principal: '+principal)
        print('01/01/26 00:00:00 01/02/26 00:00:00 krbtgt/ISH.TEST@ISH.TEST')
elif name == 'kinit':
    if args == ['-R']:
        if not os.environ.get('TEST_RENEW_OK'): sys.exit(1)
        (h/'ticket').write_text('testuser@ISH.TEST')
        sys.exit(0)
    if os.environ.get('TEST_KINIT_FAIL'): sys.exit(1)
    (h/'ticket').write_text(os.environ.get('TEST_KINIT_PRINCIPAL', args[0]))
elif name == 'ssh':
    if '-G' in args: print(os.environ['TEST_POLICY'] if args[-1] != 'ordinary' else 'gssapiauthentication no')
    else:
        print('testuser')
        sys.exit(int(os.environ.get('TEST_SSH_RC', '0')))
elif name == 'fzf':
    print(sys.stdin.readline().strip())
''')
        helper.chmod(0o755)
        for name in ('kinit', 'klist', 'ssh', 'fzf', 'tmux-agent-workbench'):
            (self.bin / name).symlink_to(helper)

    def run_connect(self, *args, tty=False, success=True, entry=SCRIPT):
        slave = master = None
        if tty:
            import pty
            master, slave = pty.openpty()
        try:
            result = subprocess.run(['sh', str(entry), *args], env=self.env,
                                    stdin=slave if tty else subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    text=True, timeout=10)
        finally:
            if master is not None:
                os.close(master)
                os.close(slave)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def calls(self, command):
        lines = self.log.read_text().splitlines() if self.log.exists() else []
        return [json.loads(line) for line in lines if json.loads(line)[0] == command]

    def test_ordinary_ssh_unchanged_and_no_kerberos_commands(self):
        self.run_connect('connect', 'ordinary')
        self.assertEqual(self.calls('ssh')[-1][1], ['ordinary'])
        self.assertFalse(self.calls('klist') or self.calls('kinit'))

    def test_valid_ticket_uses_configured_cache_and_enforces_policy(self):
        self.run_connect('connect', 'devbox', '--check', '--', '-o', 'PasswordAuthentication=yes')
        ssh = self.calls('ssh')[0]
        args = ssh[1]
        for option in ('PreferredAuthentications=gssapi-with-mic', 'PubkeyAuthentication=no',
                       'PasswordAuthentication=no', 'KbdInteractiveAuthentication=no',
                       'GSSAPIDelegateCredentials=no', 'ControlPath=none', 'StrictHostKeyChecking=yes'):
            self.assertIn(option, args)
        self.assertLess(args.index('PasswordAuthentication=no'), args.index('PasswordAuthentication=yes'))
        self.assertEqual(args[-2:], ['devbox', 'whoami'])
        self.assertEqual(ssh[2:], ['/termux/etc/krb5.conf', 'FILE:/termux/cache/ticket'])
        self.assertFalse(self.calls('kinit'))

    def test_invalid_tickets_refuse_noninteractive_ssh(self):
        for ticket in (None, 'expired', 'corrupt', 'otheruser@ISH.TEST'):
            with self.subTest(ticket=ticket):
                self.state.unlink(missing_ok=True)
                if ticket is not None:
                    self.state.write_text(ticket)
                result = self.run_connect('connect', 'devbox', success=False)
                self.assertIn('TGT missing', result.stderr)
                self.assertFalse(self.calls('ssh') or self.calls('kinit'))

    def test_interactive_reacquisition_and_recheck(self):
        self.state.write_text('otheruser@ISH.TEST')
        self.run_connect('connect', 'devbox', '--tmux', tty=True)
        self.assertEqual(self.calls('kinit')[0][1], ['testuser@ISH.TEST'])
        self.assertEqual(self.calls('ssh')[0][1][-1], 'exec tmux new-session -A -s dev')
        self.assertIn('StrictHostKeyChecking=ask', self.calls('ssh')[0][1])
        self.assertGreaterEqual(len(self.calls('klist')), 4)

    def test_check_never_prompts_even_on_a_tty(self):
        self.state.unlink()
        self.run_connect('connect', 'devbox', '--check', tty=True, success=False)
        self.assertFalse(self.calls('kinit') or self.calls('ssh'))
        self.run_connect('--check', tty=True, success=False)
        self.assertFalse(self.calls('fzf'))

    def test_kinit_error_never_launches_ssh(self):
        self.state.unlink()
        self.env['TEST_KINIT_FAIL'] = '1'
        result = self.run_connect('connect', 'devbox', tty=True, success=False)
        self.assertIn('kinit failed', result.stderr)
        self.assertFalse(self.calls('ssh'))

    def test_kinit_success_with_wrong_identity_still_refused(self):
        self.state.unlink()
        self.env['TEST_KINIT_PRINCIPAL'] = 'otheruser@ISH.TEST'
        self.run_connect('connect', 'devbox', tty=True, success=False)
        self.assertFalse(self.calls('ssh'))

    def test_print_and_host_list_do_not_authenticate(self):
        self.state.unlink()
        self.assertEqual(self.run_connect('--print').stdout.strip(), 'devbox')
        self.run_connect('hosts', 'list')
        self.assertFalse(self.calls('ssh') or self.calls('kinit') or self.calls('klist'))

    def test_unlisted_host_refused(self):
        self.run_connect('connect', 'unknown', success=False)
        self.assertFalse(self.calls('ssh'))

    def test_invalid_mapping_or_command_text_never_executed(self):
        for line in ('devbox testuser@ISH.TEST $(touch /tmp/not-allowed)',
                     'devbox -bad@ISH.TEST', 'devbox testuser@ISH.TEST\ndevbox other@ISH.TEST'):
            self.mapping.write_text(line + '\n')
            self.run_connect('connect', 'devbox', success=False)
            self.assertFalse(self.calls('ssh') or self.calls('kinit'))

    def test_workbench_recovers_ticket_and_preserves_entrypoint(self):
        self.state.unlink()
        self.run_connect('connect', 'devbox', '--workbench', tty=True)
        self.assertEqual(self.calls('tmux-agent-workbench')[0][1], ['client', 'attach', 'devbox'])
        self.assertEqual(len(self.calls('kinit')), 1)

    def test_workbench_refuses_unsafe_config(self):
        for policy in (SAFE_POLICY.replace('gssapidelegatecredentials no', 'gssapidelegatecredentials yes'),
                       SAFE_POLICY.replace('preferredauthentications gssapi-with-mic', 'preferredauthentications publickey,password'),
                       SAFE_POLICY + 'controlpath /tmp/old-master\n',
                       SAFE_POLICY.replace('stricthostkeychecking ask', 'stricthostkeychecking accept-new')):
            self.env['TEST_POLICY'] = policy
            self.run_connect('connect', 'devbox', '--workbench', success=False)
            self.assertFalse(self.calls('tmux-agent-workbench') or self.calls('kinit'))

    def test_gssapi_config_without_mapping_checks_ticket(self):
        self.mapping.unlink()
        self.run_connect('connect', 'devbox', '--tmux')
        self.assertFalse(self.calls('kinit'))
        self.assertIn('PreferredAuthentications=gssapi-with-mic', self.calls('ssh')[-1][1])

    def test_refresh_helper_recovers_before_password_prompt(self):
        helper = self.bin / 'kinit-auto-login'
        helper.write_text('#!/bin/sh\nprintf %s testuser@ISH.TEST > "$TEST_HOME/ticket"\n')
        helper.chmod(0o755)
        self.state.write_text('expired')
        self.run_connect('connect', 'devbox', '--tmux', tty=True)
        self.assertFalse(self.calls('kinit'))
        self.assertTrue(self.calls('ssh'))

    def test_renewable_ticket_recovers_without_password(self):
        self.env['TEST_RENEW_OK'] = '1'
        self.env['TEST_POLICY'] = SAFE_POLICY
        # klist can show an expired cache even when its silent check fails.
        stub = self.bin / 'stub'
        stub.write_text(stub.read_text().replace(
            "if principal in ('expired', 'corrupt'): sys.exit(1)",
            "if principal == 'expired' and args == ['-s']: sys.exit(1)\n    if principal == 'expired': principal = 'testuser@ISH.TEST'\n    if principal == 'corrupt': sys.exit(1)"))
        self.state.write_text('expired')
        self.run_connect('connect', 'devbox', tty=True)
        self.assertEqual([c[1] for c in self.calls('kinit')], [['-R']])
        self.assertTrue(self.calls('ssh'))

    def test_auto_detect_uses_configured_identity_with_no_cache(self):
        self.mapping.unlink()
        self.state.unlink()
        directory = self.conf / 'kinit-auto-login'
        directory.mkdir()
        (directory / 'kinit.env').write_text('KRB_PRINCIPAL=testuser@ISH.TEST\n')
        self.run_connect('connect', 'devbox', tty=True)
        self.assertEqual(self.calls('kinit')[0][1], ['testuser@ISH.TEST'])

    def test_failed_refresh_falls_back_to_kinit(self):
        helper = self.bin / 'kinit-auto-login'
        helper.write_text('#!/bin/sh\nexit 1\n')
        helper.chmod(0o755)
        self.state.unlink()
        self.run_connect('connect', 'devbox', tty=True)
        self.assertEqual(self.calls('kinit')[0][1], ['testuser@ISH.TEST'])
        self.assertTrue(self.calls('ssh'))

    def test_refresh_success_with_wrong_identity_does_not_bypass_check(self):
        helper = self.bin / 'kinit-auto-login'
        helper.write_text('#!/bin/sh\nprintf %s wrong@ISH.TEST > "$TEST_HOME/ticket"\n')
        helper.chmod(0o755)
        self.state.unlink()
        self.env['TEST_KINIT_FAIL'] = '1'
        self.run_connect('connect', 'devbox', tty=True, success=False)
        self.assertFalse(self.calls('ssh'))

    def test_legacy_ish_profile_is_used_without_reconfiguration(self):
        self.hosts.unlink()
        ish = self.conf / 'ish-kerberos'
        ish.mkdir()
        (ish / 'user.conf').write_text('KRB5_REALM=ISH.TEST\nKRB5_PRINCIPAL=testuser@ISH.TEST\n'
                                       'SSH_HOST=ssh.ish.test\nSSH_USER=testuser\nSSH_PORT=2222\nTMUX_SESSION=mobile\n')
        self.env.pop('KRB5_CONFIG')
        self.env.pop('KRB5CCNAME')
        self.run_connect('--tmux')
        ssh = self.calls('ssh')[0]
        self.assertIn('2222', ssh[1])
        self.assertEqual(ssh[1][-2:], ['ssh.ish.test', 'exec tmux new-session -A -s mobile'])
        self.assertEqual(ssh[2], str(ish / 'krb5.conf'))

    def test_symlink_install_and_ssh_exit_status(self):
        entry = self.bin / 'ssh-connect'
        entry.symlink_to(SCRIPT)
        self.env['TEST_SSH_RC'] = '255'
        result = self.run_connect('connect', 'devbox', entry=entry, success=False)
        self.assertEqual(result.returncode, 255)


if __name__ == '__main__':
    unittest.main()
