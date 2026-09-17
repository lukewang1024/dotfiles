"""One task runner, command boundary, and report format on every platform."""
from __future__ import annotations

import base64
import hashlib
from contextlib import contextmanager, nullcontext
import ctypes
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import traceback
from urllib.request import urlopen


class Failure(RuntimeError):
    pass


class Skip(Exception):
    pass


def detect_platform():
    if os.environ.get('TERMUX_VERSION') or os.environ.get('PREFIX') == '/data/data/com.termux/files/usr':
        return 'termux'
    if sys.platform == 'win32':
        return 'windows'
    if sys.platform == 'darwin':
        return 'macos'
    if sys.platform.startswith(('cygwin', 'msys')):
        return 'cygwin'
    if sys.platform.startswith('linux'):
        if Path('/etc/arch-release').exists():
            return 'arch'
        if Path('/etc/lsb-release').exists() and 'CHROMEOS_RELEASE_' in Path('/etc/lsb-release').read_text(encoding='utf-8'):
            return 'chromeos'
        if Path('/etc/debian_version').exists():
            return 'debian'
    raise Failure('Unsupported platform; use --platform with --dry-run to inspect another platform.')


class Reporter:
    def __init__(self, state: Path, title: str, stream=None):
        self.stream = stream or sys.stderr
        parent = state / 'dotfiles/bootstrap'
        parent.mkdir(parents=True, exist_ok=True)
        self.directory = Path(tempfile.mkdtemp(prefix=time.strftime('%Y%m%dT%H%M%S-'), dir=parent))
        self.log_path = self.directory / 'output.log'
        fd = os.open(self.log_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        self.log = os.fdopen(fd, 'w', encoding='utf-8', buffering=1)
        self.results = []
        self.stack = []
        self.started = time.monotonic()
        self.lock = threading.RLock()
        self.paused = False
        self.operation_name = ''
        self.closed = False
        self.tty = self.stream.isatty() and os.environ.get('TERM') != 'dumb'
        if self.tty and os.name == 'nt':
            handle = ctypes.windll.kernel32.GetStdHandle(-12)
            mode = ctypes.c_ulong()
            self.tty = bool(ctypes.windll.kernel32.GetConsoleMode(handle, ctypes.byref(mode)) and
                            ctypes.windll.kernel32.SetConsoleMode(handle, mode.value | 4))
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self._tick, daemon=True)
        self.say(f'Dotfiles | {title}\nLog: {self.log_path}\n')
        if self.tty:
            self.thread.start()

    def say(self, text):
        with self.lock:
            if self.tty:
                self.stream.write('\r\033[2K')
            self.stream.write(text + '\n')
            self.stream.flush()

    def _tick(self):
        tick = 0
        while not self.stop.wait(.15):
            with self.lock:
                if not self.stack or self.paused:
                    continue
                root, current = self.stack[0], self.stack[-1]
                spinner = '|/-\\'[tick % 4]
                text = f"  {spinner} {root['name']}"
                if current is not root:
                    text += ' / ' + current['name']
                if self.operation_name:
                    text += ' / ' + self.operation_name
                text += f" ({time.monotonic() - root['started']:.0f}s)"
                width = max(10, shutil.get_terminal_size((80, 24)).columns - 1)
                self.stream.write('\r\033[2K' + text[:width])
                self.stream.flush()
                tick += 1

    @contextmanager
    def task(self, name):
        row = {'name': name, 'started': time.monotonic(), 'status': 'OK', 'depth': len(self.stack)}
        with self.lock:
            self.stack.append(row)
        self.log.write(f'\n>>> {name}\n')
        if not self.tty:
            self.say('  ... ' + ' / '.join(item['name'] for item in self.stack))
        try:
            yield
        except Skip as exc:
            row.update(status='SKIP', detail=str(exc))
            self.log.write(str(exc) + '\n')
        except BaseException as exc:
            row.update(status='FAIL', detail=str(exc))
            traceback.print_exc(file=self.log)
            raise
        finally:
            with self.lock:
                self.stack.pop()
                row['seconds'] = round(time.monotonic() - row.pop('started'), 2)
                self.results.append(row)
                self.log.write(f"<<< {name}: {row['status']}\n")
                if row['depth'] == 0:
                    self.say(f"  {row['status']:<4} {name} ({row['seconds']:.1f}s)")

    @contextmanager
    def operation(self, name):
        with self.lock:
            previous, self.operation_name = self.operation_name, name
        if not self.tty:
            self.say('      > ' + name)
        try:
            yield
        finally:
            with self.lock:
                self.operation_name = previous

    @contextmanager
    def interactive(self, label):
        self.paused = True
        self.say(label)
        self.log.write('[interactive: input and output are not recorded]\n')
        try:
            yield
        finally:
            self.paused = False

    def close(self):
        if self.closed:
            return
        self.closed = True
        self.stop.set()
        if self.thread.is_alive():
            self.thread.join()
        categories = [r for r in self.results if r['depth'] == 0]
        failed = [r for r in self.results if r['status'] == 'FAIL']
        status = 'FAILED' if failed else 'DONE'
        self.say(f'\n{status} | {len(categories)} categories | {time.monotonic() - self.started:.1f}s')
        for row in categories:
            self.say(f"  {row['status']:<4} {row['name']} ({row['seconds']:.1f}s)")
        for row in failed:
            self.say(f"  - {row['name']}: {row.get('detail', '')}")
        self.say(f'Details: {self.log_path}')
        path = self.directory / 'results.json'
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump({'status': status, 'tasks': self.results}, stream, ensure_ascii=False, indent=2)
        self.log.close()


class Context:
    def __init__(self, repo, platform, *, dry_run=False, home=None, env=None, reporter=None):
        self.repo = Path(repo).resolve()
        self.platform = platform
        self.dry_run = dry_run
        self.home = Path(home) if home is not None else Path.home()
        self.env = dict(os.environ if env is None else env)
        self.env['PYTHONUTF8'] = '1'
        self.env.setdefault('LOCALAPPDATA', str(self.home / 'AppData/Local'))
        self.env.setdefault('APPDATA', str(self.home / 'AppData/Roaming'))
        # Context-owned paths, never a mutation of the process HOME.
        defaults = {'XDG_CONFIG_HOME': self.home / '.config', 'XDG_DATA_HOME': self.home / '.local/share',
                    'XDG_STATE_HOME': self.home / '.local/state', 'XDG_CACHE_HOME': self.home / '.cache'}
        if platform == 'windows':
            defaults['XDG_STATE_HOME'] = Path(self.env.get('LOCALAPPDATA', str(self.home / 'AppData/Local'))) / 'State'
            defaults['XDG_CACHE_HOME'] = Path(self.env.get('LOCALAPPDATA', str(self.home / 'AppData/Local'))) / 'Cache'
        for key, value in defaults.items():
            self.env.setdefault(key, str(value))
        self.config, self.data, self.state, self.cache = (Path(self.env[k]) for k in defaults)
        self.bin = self.home / '.local/bin'
        self.reporter = reporter
        self.events = []
        self.active = []
        self.tasks = {}
        self.validating_sudo = False
        self.variables = dict(HOME=str(self.home), repo_path=str(self.repo),
                              config_dir=str(self.repo / 'config'), util_dir=str(self.repo / 'util'),
                              bin_dir=str(self.bin), DOTFILES_PLATFORM=platform)
        # Reuse the declarative exports used by login shells, without sourcing
        # shell code. Only literal variable interpolation is accepted.
        for line in (self.repo / 'config/sh/xdg-ninja-patch.sh').read_text(encoding='utf-8').splitlines():
            match = re.fullmatch(r'export (\w+)="([^"]*)"', line)
            if match and match[1] != 'XAUTHORITY':
                self.env.setdefault(match[1], self.expand(match[2]))
        self.refresh_path()

    def expand(self, text):
        text = str(text)
        if text == '~' or text.startswith('~/'):
            text = str(self.home) + text[1:]
        values = dict(self.env, **self.variables)
        def replace(match):
            key = match[1] or match[2]
            if key not in values:
                raise Failure(f'Unknown path variable: {key}')
            return str(values[key])
        return re.sub(r'\$\{(\w+)\}|\$(\w+)', replace, text)

    def path(self, text):
        return Path(self.expand(text))

    def refresh_path(self):
        paths = [self.bin, self.data / 'pnpm', self.data / 'cargo/bin']
        paths += [self.home / 'scoop/shims', Path('/opt/homebrew/bin'), Path('/home/linuxbrew/.linuxbrew/bin'), Path('/usr/local/bin')]
        paths += [self.data / f'anyenv/envs/{name}/bin' for name in ('goenv', 'nodenv', 'pyenv', 'rbenv')]
        paths += [self.data / f'anyenv/envs/{name}/shims' for name in ('goenv', 'nodenv', 'pyenv', 'rbenv')]
        paths += [self.data / 'anyenv/bin', self.data / 'gem/bin']
        old = self.env.get('PATH', '').split(os.pathsep)
        self.env['PATH'] = os.pathsep.join(dict.fromkeys([str(p) for p in paths] + old))

    def exists(self, command):
        return shutil.which(str(command), path=self.env['PATH']) is not None

    def record(self, kind, **data):
        self.events.append(dict(kind=kind, task=list(self.active), **data))
        if self.reporter:
            self.reporter.log.write(json.dumps(dict(kind=kind, **data), ensure_ascii=False) + '\n')

    def task(self, name, *args):
        if name not in self.tasks:
            raise Failure(f'Unknown task: {name}')
        self.active.append(name)
        self.record('task', name=name, arguments=list(args))
        try:
            if self.reporter:
                with self.reporter.task(name.replace('_', ' ')):
                    self.tasks[name](self, *args)
            else:
                self.tasks[name](self, *args)
        except Skip:
            pass
        finally:
            self.active.pop()

    def command(self, *argv, capture=False, input=None, cwd=None, env=None, interactive=False, check=True, expand=False, output_file=None):
        argv = [self.expand(a) if expand else str(a) for a in argv]
        self.record('command', argv=argv, cwd=str(cwd) if cwd else None, interactive=interactive)
        if self.dry_run:
            return '' if capture else 0
        if argv[0] == 'sudo' and os.name != 'nt' and self.platform != 'cygwin' and not self.validating_sudo:
            # Authenticate visibly before output capture and detached process
            # groups remove access to the controlling terminal.
            self.validating_sudo = True
            try:
                if self.command('sudo', '-n', '-v', check=False):
                    if not sys.stdin.isatty():
                        raise Failure('sudo authentication required; rerun in an interactive terminal')
                    self.command('sudo', '-v', interactive=True)
            finally:
                self.validating_sudo = False
        # Platform tasks never implement terminal rendering or redirect streams.
        label = ' '.join([Path(argv[0]).name, *argv[1:]])
        for marker in ('-EncodedCommand', '-Command', '-c', '-e', '--command'):
            if marker in argv:
                label = ' '.join([Path(argv[0]).name, *argv[1:argv.index(marker)]]) + ' (script)'
                break
        label = label.replace('\n', ' ')[:180]
        with self.reporter.operation(label) if self.reporter else nullcontext():
            if output_file is not None:
                if capture or interactive:
                    raise ValueError('output_file cannot be combined with capture or interactive')
                target = self.path(output_file)
                target.parent.mkdir(parents=True, exist_ok=True)
                fd, tmp = tempfile.mkstemp(dir=target.parent)
                try:
                    with os.fdopen(fd, 'wb') as stream:
                        result = self._command(argv, input=input, cwd=cwd, env=env, check=check, output_file=stream)
                    if result == 0:
                        os.replace(tmp, target)
                    return result
                finally:
                    Path(tmp).unlink(missing_ok=True)
            return self._command(argv, capture=capture, input=input, cwd=cwd, env=env, interactive=interactive, check=check)

    def _command(self, argv, *, capture=False, input=None, cwd=None, env=None, interactive=False, check=True, output_file=None):
        child_env = dict(self.env, **(env or {}))
        resolved = shutil.which(argv[0], path=child_env['PATH'])
        if resolved:
            argv[0] = resolved
        # Scoop and other Windows tools are cmd/PowerShell shims, not PE files.
        # Encode argv as data; do not interpolate package names into shell code.
        if os.name == 'nt' and Path(argv[0]).suffix.lower() in ('.ps1', '.cmd', '.bat'):
            encoded_args = base64.b64encode(json.dumps(argv).encode()).decode()
            script = ("$ErrorActionPreference='Stop'; $global:LASTEXITCODE=0; "
                      "$a = @(ConvertFrom-Json ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" + encoded_args + "')))); "
                      "$cmd = $a[0]; $tail = @($a | Select-Object -Skip 1); & $cmd @tail; $ok=$?; "
                      "if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; if (!$ok) { exit 1 }; exit 0")
            argv = self.powershell_argv(script)
        output = self.reporter.log if self.reporter else subprocess.DEVNULL
        options = dict(cwd=cwd, env=child_env, stdin=subprocess.PIPE if input is not None else subprocess.DEVNULL,
                       stdout=output_file if output_file is not None else (subprocess.PIPE if capture else output), stderr=output,
                       start_new_session=os.name != 'nt')
        if interactive:
            options.update(stdin=None, stdout=None, stderr=None, start_new_session=False)
        @contextmanager
        def visible():
            if interactive and self.reporter:
                with self.reporter.interactive('Input required: ' + Path(argv[0]).name):
                    yield
            else:
                yield
        with visible():
            proc = subprocess.Popen(argv, **options)
            try:
                out, _ = proc.communicate(input.encode() if isinstance(input, str) else input)
            except BaseException:
                if proc.poll() is None:
                    if os.name == 'nt':
                        subprocess.run(['taskkill', '/PID', str(proc.pid), '/T', '/F'], stdout=output, stderr=output)
                    else:
                        os.killpg(proc.pid, signal.SIGTERM)
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                raise
        if capture and out and self.reporter:
            self.reporter.log.write(out.decode('utf-8', errors='replace'))
        if check and proc.returncode:
            raise Failure(f'{Path(argv[0]).name} exited with status {proc.returncode}')
        self.refresh_path()
        return (out or b'').decode('utf-8', errors='replace') if capture else proc.returncode

    def powershell_argv(self, script):
        executable = 'pwsh.exe' if self.exists('pwsh.exe') else 'powershell.exe'
        script = '$OutputEncoding=[Text.UTF8Encoding]::new($false); [Console]::OutputEncoding=$OutputEncoding; ' + script
        encoded = base64.b64encode(script.encode('utf-16le')).decode()
        return [executable, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encoded]

    def ps(self, script, **kwargs):
        # Only platform API snippets live here; no task orchestration or UI.
        return self.command(*self.powershell_argv("$ErrorActionPreference='Stop'; " + script), **kwargs)

    def mkdir(self, path):
        path = self.path(path)
        self.record('mkdir', path=str(path))
        if not self.dry_run:
            path.mkdir(parents=True, exist_ok=True)

    def write(self, path, text, mode=0o600, *, privileged=False):
        path = self.path(path)
        self.record('write', path=str(path), bytes=len(text.encode()), privileged=privileged)
        if self.dry_run:
            return
        if privileged:
            self.mkdir(self.cache / 'dotfiles')
            fd, tmp = tempfile.mkstemp(dir=self.cache / 'dotfiles')
            try:
                with os.fdopen(fd, 'w', encoding='utf-8') as stream:
                    stream.write(text)
                self.command('sudo', 'mkdir', '-p', path.parent)
                self.command('sudo', 'install', '-m', oct(mode)[2:], tmp, path)
            finally:
                Path(tmp).unlink(missing_ok=True)
            return
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=path.parent)
        try:
            with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as stream:
                stream.write(text)
            os.chmod(tmp, mode)
            os.replace(tmp, path)
        finally:
            Path(tmp).unlink(missing_ok=True)

    def backup(self, path):
        path = self.path(path)
        if not (path.exists() or path.is_symlink()):
            return
        target = Path(str(path) + '~')
        if target.exists() or target.is_symlink():
            target = Path(str(path) + f'.backup-{time.time_ns()}')
        self.record('backup', source=str(path), target=str(target))
        if not self.dry_run:
            path.rename(target)

    def link(self, source, target, *, allow_missing=False):
        source, target = self.path(source), self.path(target)
        self.record('link', source=str(source), target=str(target))
        if self.dry_run:
            return
        if not source.exists() and not allow_missing:
            raise Failure(f'Missing link source: {source}')
        if target.is_symlink() and target.resolve() == source.resolve():
            return
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.is_symlink():
            target.unlink()
        else:
            self.backup(target)
        target.symlink_to(source, target_is_directory=source.is_dir())

    def copy(self, source, target, *, privileged=False):
        source, target = self.path(source), self.path(target)
        self.record('copy', source=str(source), target=str(target), privileged=privileged)
        if not self.dry_run:
            if privileged:
                self.command('sudo', 'install', '-m', '644', source, target)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)

    def download(self, url, target):
        target = self.path(target)
        self.record('download', url=url, target=str(target))
        if not self.dry_run:
            target.parent.mkdir(parents=True, exist_ok=True)
            fd, tmp = tempfile.mkstemp(dir=target.parent)
            try:
                with os.fdopen(fd, 'wb') as out, urlopen(url, timeout=120) as response:
                    shutil.copyfileobj(response, out)
                os.replace(tmp, target)
            finally:
                Path(tmp).unlink(missing_ok=True)
        return target

    def installer(self, url, interpreter, *args, env=None, interactive=False):
        filename = url.rsplit('/', 1)[-1] or 'installer'
        if interpreter == 'powershell' and not filename.endswith('.ps1'):
            filename += '.ps1'
        target = self.cache / 'dotfiles/installers' / hashlib.sha256(url.encode()).hexdigest()[:16] / filename
        self.download(url, target)
        if interpreter == 'powershell':
            # Pass a downloaded script as a file with native exit propagation.
            return self.command('powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', target, *args,
                                env=env, interactive=interactive, cwd=target.parent)
        return self.command(interpreter, target, *args, env=env, interactive=interactive, cwd=target.parent)

    def sync_repo(self, path, url):
        path = self.path(path)
        if (path / '.git').exists():
            self.command('git', '-C', path, 'pull', '--ff-only')
        else:
            self.backup(path)
            self.command('git', 'clone', '--depth', '1', url, path)

    def prompt(self, label, default=''):
        self.record('prompt', label=label)
        if self.dry_run:
            return default
        if not sys.stdin.isatty():
            raise Failure(f'Interactive terminal required: {label}')
        with self.reporter.interactive(label + (f' [{default}]' if default else '') + ':'):
            return input() or default

    def note(self, text):
        self.record('note', text=text)
        if self.reporter:
            self.reporter.say('  Note: ' + text)
