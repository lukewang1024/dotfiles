"""Menu transport for the separately distributed Hyper Palette (Python 3.7+).

Only action IDs cross this boundary. The resident renderer never executes them.
Local IPC uses loopback JSON with a per-user random token, not pickle or a shell.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import re
import select
import socket
import subprocess
import sys
import threading
import time
import uuid

from localize import catalog, keywords, system_language, translate

LIMIT = 1024 * 1024


def data_home():
    fallback = Path(os.environ.get('LOCALAPPDATA', str(Path.home() / '.local/share')))
    return Path(os.environ.get('XDG_DATA_HOME', str(fallback))) / 'hyper-palette'


def binary_path():
    root = data_home() / 'current'
    if sys.platform == 'darwin':
        return root / 'Hyper Palette Prototype.app/Contents/MacOS/hyper-palette'
    return root / ('hyper-palette.exe' if os.name == 'nt' else 'hyper-palette')


def state_home():
    fallback = Path(os.environ.get('LOCALAPPDATA', str(Path.home() / '.local/state')))
    base = Path(os.environ.get('XDG_STATE_HOME', str(fallback))) / 'hyper-palette'
    # xbindkeys expands :1 to :1.0. Screen zero is implicit in X11 DISPLAY;
    # sharing an identity avoids connecting to a stale parallel renderer.
    display = re.sub(r'(:\d+)\.0$', r'\1', os.environ.get('DISPLAY', ''))
    identity = str(binary_path()) + display + os.environ.get('SESSIONNAME', '')
    root = base / hashlib.sha256(identity.encode()).hexdigest()[:12]
    root.mkdir(parents=True, exist_ok=True)
    if os.name != 'nt':
        root.chmod(0o700)
    return root


def send(stream, value):
    payload = (json.dumps(value, ensure_ascii=False) + '\n').encode('utf-8')
    if len(payload) > LIMIT:
        raise ValueError('IPC frame too large')
    stream.write(payload)
    stream.flush()


def receive(stream):
    line = stream.readline(LIMIT + 1)
    if not line or len(line) > LIMIT:
        raise ValueError('IPC closed or oversized frame')
    return json.loads(line.decode('utf-8'))


def request(platform, lang):
    data = json.loads(Path(__file__).with_name('keys.json').read_text(encoding='utf-8'))
    labels = catalog(data)
    menus = {}
    for name in ('config', 'clipboard'):
        rows = list(data['menus'][name])
        if name == 'config' and platform == 'mac':
            rows.append(['b', 'Sync Alfred blacklist', 'clipboard.syncBlacklist'])
        items = []
        for key, title, action in rows:
            item = dict(id=action, title=translate(labels, action, lang),
                        detail='', shortcut=key,
                        keywords=keywords(labels, action))
            if action == 'menu.clipboard':
                item['submenu'] = action
            items.append(item)
        menus['menu.' + name] = dict(title=translate(labels, 'menu.' + name, lang), items=items, quick=True)
    return dict(request_id=str(uuid.uuid4()), root='menu.config', menus=menus)


def allowed_actions(value):
    return {item['id'] for menu in value['menus'].values() for item in menu['items']
            if not item.get('submenu') and not item.get('disabled')}


def daemon():
    root = state_home()
    token = secrets.token_hex(32)
    listener = socket.socket()
    listener.bind(('127.0.0.1', 0))
    listener.listen(8)
    flags = {'creationflags': subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {}
    process = subprocess.Popen([str(binary_path())], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, **flags)
    ready = receive(process.stdout)
    if ready.get('type') != 'ready':
        raise RuntimeError('Renderer protocol handshake failed')
    if 'dynamic_pages' not in ready.get('capabilities', []):
        process.terminate()
        process.wait(timeout=5)
        raise RuntimeError('Hyper Palette is outdated; install the current pinned artifact')
    clients = {}
    lock = threading.RLock()

    def dispatch():
        try:
            while True:
                event = receive(process.stdout)
                with lock:
                    client = clients.get(event.get('request_id'))
                    if client:
                        try:
                            send(client, event)
                        except (OSError, ValueError):
                            pass
        finally:
            # The descriptor is only trusted after an authenticated ping.
            os._exit(1)

    def handle(connection):
        rid = None
        try:
            with connection, connection.makefile('rwb') as stream:
                connection.settimeout(5)
                message = receive(stream)
                if not secrets.compare_digest(str(message.get('token', '')), token):
                    return
                if message.get('type') == 'ping':
                    send(stream, {'type': 'ready'})
                    return
                if message.get('type') == 'quit':
                    with lock:
                        send(process.stdin, {'type': 'quit'})
                    return
                value = message['request']
                rid = value['request_id']
                with lock:
                    clients[rid] = stream
                    send(process.stdin, {'type': 'show', 'request': value})
                connection.settimeout(None)
                # Keep one authenticated session for dynamic pages and navigation.
                while True:
                    command = receive(stream)
                    if command.get('type') == 'push':
                        if command['request']['request_id'] != rid:
                            raise ValueError('Mismatched request ID')
                    elif command.get('type') in ('navigate', 'hide'):
                        if command.get('request_id') != rid:
                            raise ValueError('Mismatched request ID')
                    else:
                        raise ValueError('Unsupported session command')
                    with lock:
                        send(process.stdin, command)
        except (OSError, ValueError, KeyError):
            pass
        finally:
            if rid:
                with lock:
                    clients.pop(rid, None)
                    send(process.stdin, {'type': 'hide', 'request_id': rid})

    threading.Thread(target=dispatch, daemon=True).start()
    descriptor = root / 'endpoint.json'
    temporary = root / ('endpoint-' + token[:8])
    fd = os.open(str(temporary), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as output:
        json.dump(dict(port=listener.getsockname()[1], token=token, pid=os.getpid()), output)
    os.replace(str(temporary), str(descriptor))
    while True:
        connection, _ = listener.accept()
        threading.Thread(target=handle, args=(connection,), daemon=True).start()


def endpoint():
    value = json.loads((state_home() / 'endpoint.json').read_text())
    with socket.create_connection(('127.0.0.1', value['port']), timeout=1) as connection:
        with connection.makefile('rwb') as stream:
            send(stream, dict(type='ping', token=value['token']))
            if receive(stream).get('type') != 'ready':
                raise ValueError('Invalid handshake')
    return value


def ensure_host():
    try:
        return endpoint()
    except (OSError, ValueError, KeyError):
        pass
    if not binary_path().is_file():
        raise RuntimeError('Hyper Palette is not installed')
    root = state_home()
    lock = root / 'starting'
    owner = False
    try:
        lock.mkdir()
        owner = True
    except FileExistsError:
        if time.time() - lock.stat().st_mtime > 30:
            lock.rmdir()
            return ensure_host()
    try:
        if owner:
            flags = {'creationflags': subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {'start_new_session': True}
            with (root / 'host.log').open('ab') as log:
                subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--daemon'],
                                 stdin=subprocess.DEVNULL, stdout=log, stderr=log, **flags)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            try:
                return endpoint()
            except (OSError, ValueError, KeyError):
                time.sleep(.05)
        raise RuntimeError('Hyper Palette startup timed out')
    finally:
        if owner:
            lock.rmdir()


def stop_host():
    try:
        address = endpoint()
    except (OSError, ValueError, KeyError):
        return
    with socket.create_connection(('127.0.0.1', address['port']), timeout=2) as connection:
        with connection.makefile('rwb') as stream:
            send(stream, dict(type='quit', token=address['token']))
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        try:
            endpoint()
        except (OSError, ValueError, KeyError):
            return
        time.sleep(.05)
    raise RuntimeError('Renderer did not stop; refusing to replace a running installation')


def show(platform, lang=None):
    address = ensure_host()
    value = request(platform, lang or system_language())
    allowed = allowed_actions(value)
    with socket.create_connection(('127.0.0.1', address['port']), timeout=5) as connection:
        with connection.makefile('rwb') as stream:
            send(stream, dict(type='show', token=address['token'], request=value))
            # Startup must acknowledge promptly; user selection has no timeout.
            while True:
                event = receive(stream)
                if event.get('request_id') != value['request_id']:
                    raise ValueError('Mismatched request ID')
                if event['type'] == 'shown':
                    connection.settimeout(None)
                elif event['type'] == 'action':
                    if event.get('action') not in allowed:
                        raise ValueError('Renderer returned an unknown action')
                    return event
                elif event['type'] == 'dismissed':
                    return event
                elif event['type'] == 'error':
                    raise RuntimeError(event.get('message', 'Renderer rejected request'))


class Session:
    """One resident window; adapters own action IDs and lazy page data."""
    def __init__(self, value):
        address = ensure_host()
        self.rid = value['request_id']
        self.allowed = allowed_actions(value)
        self.connection = socket.create_connection(('127.0.0.1', address['port']), timeout=5)
        self.stream = self.connection.makefile('rwb')
        self.lock = threading.RLock()
        send(self.stream, dict(type='show', token=address['token'], request=value))

    def command(self, command):
        with self.lock:
            if command['type'] == 'push':
                if command['request']['request_id'] != self.rid:
                    raise ValueError('Mismatched request ID')
                self.allowed.update(allowed_actions(command['request']))
            elif command['type'] in ('navigate', 'hide'):
                if command.get('request_id') != self.rid:
                    raise ValueError('Mismatched request ID')
            else:
                raise ValueError('Unsupported command')
            send(self.stream, command)

    def events(self):
        while True:
            event = receive(self.stream)
            if event.get('request_id') != self.rid:
                raise ValueError('Mismatched request ID')
            if event['type'] == 'shown':
                self.connection.settimeout(None)
            if event['type'] == 'action' and event.get('action') not in self.allowed:
                raise ValueError('Renderer returned an unknown action')
            yield event
            if event['type'] in ('error', 'dismissed') or (event['type'] == 'action' and not event.get('keep_open')):
                return

    def close(self):
        try:
            self.connection.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        self.stream.close()
        self.connection.close()


def interactive(directory=None):
    """JSONL stdin/stdout for Lua; private numbered files for AHK v1."""
    root = Path(directory) if directory else None
    done = threading.Event()
    input_buffer = bytearray()
    output_lock = threading.Lock()
    def output(event):
        with output_lock:
            sys.stdout.write(json.dumps(event, ensure_ascii=False) + '\n')
            sys.stdout.flush()
    def command(number):
        if root:
            path = root / ('command-%d.json' % number)
            while not done.wait(.02):
                if path.exists():
                    value = json.loads(path.read_text(encoding='utf-8-sig'))
                    path.unlink()
                    return value
            return None
        # Never block a daemon thread in BufferedReader.readline(): Python
        # aborts during finalization if that thread still owns stdin's lock.
        # POSIX pipes are cancellable with select; Windows uses numbered files.
        while not done.is_set():
            newline = input_buffer.find(b'\n')
            if newline >= 0:
                line = bytes(input_buffer[:newline + 1])
                del input_buffer[:newline + 1]
                if len(line) > LIMIT:
                    raise ValueError('Oversized stdin frame')
                return json.loads(line.decode('utf-8'))
            if len(input_buffer) > LIMIT:
                raise ValueError('Oversized stdin frame')
            readable, _, _ = select.select([sys.stdin.fileno()], [], [], .05)
            if readable:
                chunk = os.read(sys.stdin.fileno(), 4096)
                if not chunk:
                    raise ValueError('Adapter stdin closed')
                input_buffer.extend(chunk)
        return None
    initial = command(0)
    session = Session(initial['request'])
    def forward():
        try:
            number = 1
            while not done.is_set():
                value = command(number)
                if value is None:
                    break
                session.command(value)
                if not root:
                    output(dict(type='ack', request_id=session.rid))
                number += 1
        except (OSError, ValueError, KeyError, TypeError):
            try:
                session.command(dict(type='hide', request_id=session.rid))
            except OSError:
                pass
    worker = threading.Thread(target=forward)
    worker.start()
    try:
        for number, event in enumerate(session.events()):
            if root:
                temporary = root / ('event-%d.tmp' % number)
                # Only generated ASCII item IDs cross the AHK result boundary.
                temporary.write_text('\n'.join([event['type'], event.get('action', event.get('reason', '')), '1' if event.get('keep_open') else '0']), encoding='utf-8')
                os.replace(str(temporary), str(root / ('event-%d.txt' % number)))
            else:
                output(event)
    finally:
        done.set()
        # Wake a pending socket write before joining; then close buffered IO
        # only once no other thread can still be using it.
        try:
            session.connection.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        worker.join()
        session.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--daemon', action='store_true')
    parser.add_argument('--warm', action='store_true')
    parser.add_argument('--stop', action='store_true')
    parser.add_argument('--platform', choices=['mac', 'windows', 'linux'], default='linux')
    parser.add_argument('--lang', choices=['zh', 'en'])
    parser.add_argument('--result-file')
    parser.add_argument('--interactive', action='store_true')
    parser.add_argument('--session-dir')
    args = parser.parse_args()
    if args.interactive and os.name == 'nt' and not args.session_dir:
        parser.error('Use --session-dir for the Windows adapter')
    if args.interactive or args.session_dir:
        interactive(args.session_dir)
        return
    if args.daemon:
        daemon()
        return
    if args.stop:
        stop_host()
        return
    try:
        result = {'type': 'ready'} if args.warm and ensure_host() else show(args.platform, args.lang)
    except Exception as error:
        result = {'type': 'error', 'message': str(error)}
    if args.result_file:
        target = Path(args.result_file)
        temporary = target.with_suffix('.tmp')
        temporary.write_text(result['type'] + '\n' + result.get('action', result.get('reason', result.get('message', ''))), encoding='utf-8')
        os.replace(str(temporary), str(target))
    else:
        print(json.dumps(result, ensure_ascii=False))
    return 1 if result['type'] == 'error' else 0


if __name__ == '__main__':
    sys.exit(main())
