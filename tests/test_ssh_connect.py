"""Connection policy and interactive ticket recovery; no external hosts/secrets."""
import contextlib
import json
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
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


class _SSHConsole:
    """Run the entrypoint on a controlling PTY, including real terminal signals."""
    def __init__(self, env, args):
        import fcntl
        import pty
        import termios
        self.master, self.slave = pty.openpty()
        self.original_settings = termios.tcgetattr(self.slave)
        self.output = b''
        self.position = 0

        def own_terminal():
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)

        try:
            self.process = subprocess.Popen(
                ['sh', str(SCRIPT), *args], env=env,
                stdin=self.slave, stdout=self.slave, stderr=self.slave,
                preexec_fn=own_terminal)
        except BaseException:
            os.close(self.master)
            os.close(self.slave)
            raise

    def expect(self, message, timeout=10):
        pattern = message.encode()
        deadline = time.monotonic() + timeout
        while True:
            index = self.output.find(pattern, self.position)
            if index >= 0:
                self.position = index + len(pattern)
                return
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError(f'Expected {message!r}; terminal output: {self.output!r}')
            if select.select([self.master], [], [], min(remaining, .1))[0]:
                try:
                    chunk = os.read(self.master, 65536)
                except OSError:
                    chunk = b''
                if not chunk:
                    raise AssertionError(f'Terminal closed before {message!r}: {self.output!r}')
                self.output += chunk

    def send(self, data):
        os.write(self.master, data)

    def settings(self):
        import termios
        return termios.tcgetattr(self.slave)

    def close(self):
        try:
            if self.process.poll() is None:
                os.killpg(self.process.pid, signal.SIGTERM)
                try:
                    self.process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(self.process.pid, signal.SIGKILL)
                    self.process.wait(timeout=3)
        finally:
            os.close(self.master)
            os.close(self.slave)


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
import json, os, pathlib, signal, sys
h = pathlib.Path(os.environ['TEST_HOME'])
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with (h/'calls').open('a') as out:
    out.write(json.dumps([name, args, os.environ.get('KRB5_CONFIG'), os.environ.get('KRB5CCNAME')])+'\\n')
def clock():
    return int((h/'clock').read_text()) if (h/'clock').exists() else 1000
def connection_status():
    prefix = 'TEST_SSH' if name == 'ssh' else 'TEST_WORKBENCH'
    counter = h / (name + '-attempts')
    attempt = int(counter.read_text()) if counter.exists() else 0
    counter.write_text(str(attempt + 1))
    with (h/'attempt-times').open('a') as out:
        out.write(json.dumps([name, clock()])+'\\n')
    durations = os.environ.get(prefix + '_DURATIONS', '').split(',')
    if attempt < len(durations) and durations[attempt]:
        (h/'clock').write_text(str(clock() + int(durations[attempt])))
    sequence = os.environ.get(prefix + '_SEQUENCE')
    if sequence:
        statuses = sequence.split(',')
        return int(statuses[attempt]) if attempt < len(statuses) else 99
    return int(os.environ.get(prefix + '_RC', '0'))
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
    if os.environ.get('TEST_KINIT_SECONDS'):
        (h/'clock').write_text(str(clock() + int(os.environ['TEST_KINIT_SECONDS'])))
elif name == 'ssh':
    if '-G' in args: print(os.environ['TEST_POLICY'] if args[-1] != 'ordinary' else 'gssapiauthentication no')
    else:
        print('testuser')
        sys.exit(connection_status())
elif name == 'tmux-agent-workbench':
    sys.exit(connection_status())
elif name == 'date':
    print(clock())
elif name == 'dd':
    (h/'clock').write_text(str(clock() + 1))
    if os.environ.get('TEST_EXPIRE_TICKET'): (h/'ticket').write_text('expired')
elif name == 'fzf':
    print(sys.stdin.readline().strip())
''')
        helper.chmod(0o755)
        for name in ('kinit', 'klist', 'ssh', 'fzf', 'tmux-agent-workbench', 'date', 'dd'):
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

    @contextlib.contextmanager
    def console(self, *args):
        console = _SSHConsole(self.env, args)
        try:
            yield console
        finally:
            console.close()

    def connection_times(self, command):
        path = self.home / 'attempt-times'
        lines = path.read_text().splitlines() if path.exists() else []
        return [stamp for name, stamp in map(json.loads, lines) if name == command]

    def use_real_retry_input(self):
        (self.bin / 'dd').unlink()
        (self.bin / 'date').unlink()

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

    def ssh_connections(self):
        return [call for call in self.calls('ssh') if '-G' not in call[1]]

    def test_workbench_reconnects_without_picking_the_host_again(self):
        self.env['TEST_WORKBENCH_SEQUENCE'] = '1,255,0'
        result = self.run_connect('--workbench', tty=True)
        attempts = self.calls('tmux-agent-workbench')
        self.assertEqual([call[1] for call in attempts], [['client', 'attach', 'devbox']] * 3)
        self.assertEqual(self.connection_times('tmux-agent-workbench'), [1000, 1001, 1003])
        self.assertEqual(len(self.calls('fzf')), 1)
        self.assertIn('Press Enter to retry now; Ctrl-C to exit', result.stderr)
        self.assertFalse(self.calls('kinit'))

    def test_tmux_reconnects_with_the_same_command_and_options(self):
        self.env['TEST_SSH_SEQUENCE'] = '255,255,0'
        self.run_connect('connect', 'ordinary', '--tmux', '--', '-p', '2222',
                         '-o', 'ServerAliveInterval=60', tty=True)
        attempts = self.ssh_connections()
        self.assertEqual(len(attempts), 3)
        self.assertTrue(all(call[1] == attempts[0][1] for call in attempts))
        self.assertIn('2222', attempts[0][1])
        alive = [option for option in attempts[0][1] if option.startswith('ServerAliveInterval=')]
        self.assertEqual(alive[0], 'ServerAliveInterval=60')
        self.assertEqual(attempts[0][1][-2], 'ordinary')
        self.assertEqual(self.connection_times('ssh'), [1000, 1001, 1003])
        self.assertFalse(self.calls('klist') or self.calls('kinit'))

    def test_tmux_reconnect_keeps_kerberos_policy_and_session(self):
        self.env['TEST_SSH_SEQUENCE'] = '255,0'
        self.run_connect('connect', 'devbox', '--tmux', tty=True)
        attempts = self.ssh_connections()
        self.assertEqual(len(attempts), 2)
        for call in attempts:
            args = call[1]
            self.assertEqual(args[-2:], ['devbox', 'exec tmux new-session -A -s dev'])
            self.assertIn('PreferredAuthentications=gssapi-with-mic', args)
            self.assertIn('ControlPath=none', args)
            self.assertIn('TCPKeepAlive=no', args)
            alive = [option for option in args if option.startswith('ServerAliveInterval=')]
            self.assertEqual(alive[0], 'ServerAliveInterval=5')
        self.assertGreaterEqual(len(self.calls('klist')), 4)

    def test_reconnect_recovers_a_ticket_that_expired_during_the_outage(self):
        helper = self.bin / 'kinit-auto-login'
        helper.write_text('#!/bin/sh\nexit 1\n')
        helper.chmod(0o755)
        self.env['TEST_EXPIRE_TICKET'] = '1'
        self.env['TEST_WORKBENCH_SEQUENCE'] = '1,0'
        self.run_connect('connect', 'devbox', '--workbench', tty=True)
        self.assertEqual(len(self.calls('tmux-agent-workbench')), 2)
        self.assertEqual([call[1] for call in self.calls('kinit')], [['testuser@ISH.TEST']])

    def test_reconnect_refuses_a_failed_ticket_refresh(self):
        helper = self.bin / 'kinit-auto-login'
        helper.write_text('#!/bin/sh\nexit 1\n')
        helper.chmod(0o755)
        self.env.update(TEST_EXPIRE_TICKET='1', TEST_KINIT_FAIL='1', TEST_WORKBENCH_SEQUENCE='1,0')
        result = self.run_connect('connect', 'devbox', '--workbench', tty=True, success=False)
        self.assertIn('kinit failed', result.stderr)
        self.assertEqual(len(self.calls('tmux-agent-workbench')), 1)

    def test_five_retries_then_each_enter_performs_only_one_manual_attempt(self):
        self.env['TEST_WORKBENCH_SEQUENCE'] = '1,1,1,1,1,1,1,0'
        with self.console('connect', 'ordinary', '--workbench') as console:
            console.expect('automatic reconnect limit reached (5/5 retries)')
            self.assertEqual(self.connection_times('tmux-agent-workbench'),
                             [1000, 1001, 1003, 1007, 1015, 1031])
            reads = len(self.calls('dd'))
            time.sleep(.15)
            self.assertEqual(len(self.calls('tmux-agent-workbench')), 6)
            console.send(b'\n')
            console.expect('automatic reconnect limit reached (5/5 retries)')
            self.assertEqual(len(self.calls('tmux-agent-workbench')), 7)
            self.assertEqual(len(self.calls('dd')), reads)
            console.send(b'x')
            time.sleep(.15)
            self.assertEqual(len(self.calls('tmux-agent-workbench')), 7)
            console.send(b'\n')
            self.assertEqual(console.process.wait(timeout=5), 0)
            self.assertEqual(len(self.calls('tmux-agent-workbench')), 8)
            self.assertEqual(len(self.calls('dd')), reads)
            self.assertEqual(console.settings(), console.original_settings)

    def test_connection_time_does_not_consume_retry_budget(self):
        self.env.update(TEST_WORKBENCH_SEQUENCE='1,1,1,0',
                        TEST_WORKBENCH_DURATIONS='0,40,20,0')
        with self.console('connect', 'ordinary', '--workbench') as console:
            self.assertEqual(console.process.wait(timeout=5), 0)
            self.assertEqual(self.connection_times('tmux-agent-workbench'), [1000, 1001, 1043, 1067])
            self.assertEqual(len(self.calls('tmux-agent-workbench')), 4)

    def test_ticket_refresh_time_does_not_consume_retry_budget(self):
        helper = self.bin / 'kinit-auto-login'
        helper.write_text('#!/bin/sh\nexit 1\n')
        helper.chmod(0o755)
        self.env.update(TEST_EXPIRE_TICKET='1', TEST_KINIT_SECONDS='60',
                        TEST_WORKBENCH_SEQUENCE='1,0')
        with self.console('connect', 'devbox', '--workbench') as console:
            self.assertEqual(console.process.wait(timeout=5), 0)
            self.assertEqual(len(self.calls('tmux-agent-workbench')), 2)
            self.assertEqual((self.home / 'clock').read_text(), '1061')
            self.assertEqual(len(self.calls('kinit')), 1)
            self.assertEqual(console.settings(), console.original_settings)

    def test_connection_time_does_not_cut_short_backoff(self):
        self.env.update(TEST_WORKBENCH_SEQUENCE='1,1,0',
                        TEST_WORKBENCH_DURATIONS='0,58,0')
        with self.console('connect', 'ordinary', '--workbench') as console:
            self.assertEqual(console.process.wait(timeout=5), 0)
            self.assertEqual(self.connection_times('tmux-agent-workbench'), [1000, 1001, 1061])

    def test_enter_interrupts_backoff_and_restores_terminal_settings(self):
        self.use_real_retry_input()
        self.env['TEST_WORKBENCH_SEQUENCE'] = '1,1,0'
        with self.console('connect', 'ordinary', '--workbench') as console:
            console.expect('retry 2/5 in 2s.')
            started = time.monotonic()
            console.send(b'\n')
            self.assertEqual(console.process.wait(timeout=5), 0)
            self.assertLess(time.monotonic() - started, 1.5)
            self.assertEqual(len(self.calls('tmux-agent-workbench')), 3)
            self.assertEqual(console.settings(), console.original_settings)

    def test_normal_detach_does_not_reconnect(self):
        self.run_connect('connect', 'ordinary', '--workbench', tty=True)
        self.assertEqual(len(self.calls('tmux-agent-workbench')), 1)
        self.assertFalse(self.calls('dd'))

    def test_remote_command_failure_does_not_reconnect_tmux(self):
        self.env['TEST_SSH_SEQUENCE'] = '1,0'
        result = self.run_connect('connect', 'ordinary', '--tmux', tty=True, success=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(len(self.ssh_connections()), 1)
        self.assertFalse(self.calls('dd'))

    def test_noninteractive_connections_do_not_retry(self):
        self.env.update(TEST_WORKBENCH_RC='1', TEST_SSH_RC='255')
        self.run_connect('connect', 'ordinary', '--workbench', success=False)
        self.run_connect('connect', 'ordinary', '--tmux', success=False)
        self.assertEqual(len(self.calls('tmux-agent-workbench')), 1)
        self.assertEqual(len(self.ssh_connections()), 1)
        self.assertFalse(self.calls('dd'))

    def test_no_reconnect_allows_a_single_interactive_attempt(self):
        self.env.update(TEST_WORKBENCH_RC='1', TEST_SSH_RC='255')
        self.run_connect('connect', 'ordinary', '--workbench', '--no-reconnect', tty=True, success=False)
        self.run_connect('connect', 'ordinary', '--tmux', '--no-reconnect', tty=True, success=False)
        self.assertEqual(len(self.calls('tmux-agent-workbench')), 1)
        self.assertEqual(len(self.ssh_connections()), 1)
        self.assertFalse(self.calls('dd'))

    def test_plain_interactive_ssh_does_not_retry(self):
        self.env['TEST_SSH_SEQUENCE'] = '255,0'
        result = self.run_connect('connect', 'ordinary', tty=True, success=False)
        self.assertEqual(result.returncode, 255)
        self.assertEqual(len(self.ssh_connections()), 1)
        self.assertFalse(self.calls('dd'))

    def test_interrupted_transport_does_not_retry(self):
        self.env['TEST_WORKBENCH_SEQUENCE'] = '130,0'
        result = self.run_connect('connect', 'ordinary', '--workbench', tty=True, success=False)
        self.assertEqual(result.returncode, 130)
        self.assertEqual(len(self.calls('tmux-agent-workbench')), 1)
        self.assertFalse(self.calls('dd'))

    def test_ctrl_c_stops_automatic_wait_and_restores_terminal_settings(self):
        self.use_real_retry_input()
        self.env['TEST_WORKBENCH_RC'] = '1'
        with self.console('connect', 'ordinary', '--workbench') as console:
            console.expect('retry 1/5 in 1s.')
            console.send(b'\x03')
            self.assertEqual(console.process.wait(timeout=5), 130)
            self.assertEqual(len(self.calls('tmux-agent-workbench')), 1)
            self.assertEqual(console.settings(), console.original_settings)

    def test_ctrl_c_stops_manual_wait_and_restores_terminal_settings(self):
        self.env['TEST_WORKBENCH_SEQUENCE'] = '1,1,1,1,1,1'
        with self.console('connect', 'ordinary', '--workbench') as console:
            console.expect('automatic reconnect limit reached (5/5 retries)')
            console.send(b'\x03')
            self.assertEqual(console.process.wait(timeout=5), 130)
            self.assertEqual(len(self.calls('tmux-agent-workbench')), 6)
            self.assertEqual(console.settings(), console.original_settings)

    def test_symlink_install_and_ssh_exit_status(self):
        entry = self.bin / 'ssh-connect'
        entry.symlink_to(SCRIPT)
        self.env['TEST_SSH_RC'] = '255'
        result = self.run_connect('connect', 'devbox', entry=entry, success=False)
        self.assertEqual(result.returncode, 255)


if __name__ == '__main__':
    unittest.main()
