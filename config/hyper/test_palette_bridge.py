import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, MagicMock

import palette_bridge as bridge


class BridgeTests(unittest.TestCase):
    def test_display_zero_alias_shares_endpoint_but_other_screens_do_not(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {'XDG_STATE_HOME':temp}):
            def state(display):
                with patch.dict(os.environ, {'DISPLAY':display}):
                    return bridge.state_home()
            self.assertEqual(state(':1'),state(':1.0'))
            self.assertEqual(state('localhost:1'),state('localhost:1.0'))
            self.assertNotEqual(state(':1'),state(':1.1'))
            self.assertNotEqual(state(':1'),state(':2'))

    @unittest.skipIf(os.name == 'nt', 'Windows uses cancellable session-directory polling')
    def test_interactive_exits_cleanly_while_adapter_keeps_stdin_open(self):
        code = '''
import threading
import palette_bridge as bridge
received = threading.Event()
class Connection:
    def shutdown(self, how): pass
class Session:
    def __init__(self, value):
        self.rid=value['request_id']; self.connection=Connection()
    def command(self, value): received.set()
    def events(self):
        yield dict(type='shown', request_id=self.rid)
        assert received.wait(2), 'Buffered second command was lost'
        yield dict(type='action', request_id=self.rid, action='done')
    def close(self): pass
bridge.Session=Session
bridge.interactive()
'''
        process=subprocess.Popen([sys.executable,'-B','-c',code],cwd=str(Path(bridge.__file__).parent),
                                 stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        try:
            # Keep stdin open deliberately, exactly like Hammerspoon hs.task.
            process.stdin.write(b'{"type":"show","request":{"request_id":"test"}}\n{"type":"navigate","request_id":"test","action":"accept"}\n')
            process.stdin.flush()
            self.assertEqual(process.wait(timeout=5),0)
            self.assertNotIn(b'Fatal Python',process.stderr.read())
            events=[json.loads(line) for line in process.stdout.read().splitlines()]
            self.assertTrue(any(event['type']=='action' for event in events))
        finally:
            if process.poll() is None:
                process.kill();process.wait()
            process.stdin.close();process.stdout.close();process.stderr.close()

    def test_session_dynamic_whitelist_and_nonterminal_actions(self):
        import io
        connection=MagicMock()
        connection.makefile.return_value=io.BytesIO()
        value=dict(request_id='test',root='root',menus={'root':dict(title='Root',items=[dict(id='parent',navigate=True)])})
        child=dict(request_id='test',root='child',menus={'child':dict(title='Child',items=[dict(id='leaf')])})
        with patch.object(bridge,'ensure_host',return_value=dict(port=123,token='test')), patch.object(bridge.socket,'create_connection',return_value=connection):
            session=bridge.Session(value)
            session.command(dict(type='push',request=child))
            self.assertEqual(session.allowed,{'parent','leaf'})
            with self.assertRaises(ValueError):session.command(dict(type='navigate',request_id='stale',action='accept'))
            with patch.object(bridge,'receive',side_effect=[dict(type='shown',request_id='test'),dict(type='action',request_id='test',action='parent',keep_open=True),dict(type='action',request_id='test',action='leaf')]):
                self.assertEqual(len(list(session.events())),3)
            with patch.object(bridge,'receive',return_value=dict(type='action',request_id='test',action='injected')):
                with self.assertRaises(ValueError):list(session.events())
            session.close()

    def test_shortcuts_match_original_menu_configuration(self):
        data = json.loads(Path(bridge.__file__).with_name('keys.json').read_text(encoding='utf-8'))
        for platform in ('mac', 'linux', 'windows'):
            menus = bridge.request(platform, 'en')['menus']
            for name in ('config', 'clipboard'):
                self.assertTrue(menus['menu.' + name]['quick'])
                shortcuts = {item['id']: item['shortcut'] for item in menus['menu.' + name]['items']}
                for key, _, action in data['menus'][name]:
                    self.assertEqual(shortcuts[action], key)

    def test_request_graph_and_locales(self):
        for platform in ('mac', 'linux', 'windows'):
            for lang in ('en', 'zh'):
                value = bridge.request(platform, lang)
                self.assertEqual(len(value['menus']['menu.config']['items']), 9 if platform == 'mac' else 8)
                self.assertEqual(len(value['menus']['menu.clipboard']['items']), 3)
                allowed = bridge.allowed_actions(value)
                self.assertIn('system.hyperKeys', allowed)
                self.assertNotIn('menu.clipboard', allowed)
                self.assertEqual('clipboard.syncBlacklist' in allowed, platform == 'mac')
                for menu in value['menus'].values():
                    for item in menu['items']:
                        if item.get('submenu'):
                            self.assertIn(item['submenu'], value['menus'])

    def test_frame_limits_and_roundtrip(self):
        import io
        stream = io.BytesIO()
        bridge.send(stream, {'title': '中文'})
        stream.seek(0)
        self.assertEqual(bridge.receive(stream), {'title': '中文'})
        with self.assertRaises(ValueError):
            bridge.receive(io.BytesIO(b'x' * (bridge.LIMIT + 1)))
        with self.assertRaises(ValueError):
            bridge.receive(io.BytesIO())

    def test_missing_binary_is_recoverable(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with patch.object(bridge, 'state_home', return_value=root), patch.object(bridge, 'binary_path', return_value=root / 'absent'):
                with self.assertRaisesRegex(RuntimeError, 'not installed'):
                    bridge.ensure_host()


if __name__ == '__main__':
    unittest.main()
