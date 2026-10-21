import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import check_i18n as guard
import localize


class I18nGuardTests(unittest.TestCase):
    def test_catalog_rejects_missing_language_duplicates_and_placeholder_drift(self):
        for content in ('{"new.action":["New action"]}',
                        '{"new.action":["New action",""]}',
                        '{"new.action":["Open {name}","打开 {other}"]}',
                        '{"new.action":["Open","打开"],"new.action":["Run","运行"]}'):
            with self.subTest(content=content), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / 'locales.json'
                path.write_text(content)
                with self.assertRaises(ValueError):
                    localize.load_source(path)

    def test_new_actions_and_roles_require_translations(self):
        original = json.loads((guard.ROOT / 'config/hyper/keys.json').read_text())
        for change in ('binding', 'menu', 'role'):
            data = copy.deepcopy(original)
            if change == 'binding':
                data['bindings'].append({'action':'new.action'})
            elif change == 'menu':
                data['menus']['new'] = [['N', 'New action', 'new.action']]
            else:
                data['roles']['new'] = {}
            with self.subTest(change=change), self.assertRaises(ValueError):
                localize.catalog(data)

    def test_literal_feedback_and_unknown_keys_fail_on_all_platforms(self):
        labels = {'en':{'known':'Known'}, 'zh':{'known':'已知'}}
        for path, source in (
            ('new.lua', "hs.alert.show('New feature failed')"),
            ('new.lua', "return {title='Ready'}"),
            ('new.lua', "return {subText='没有会话'}"),
            ('new.lua', "return t('missing.key')"),
            ('new.ahk', 'MsgBox, New feature, "New feature failed"'),
            ('new.ahk', 'MsgBox, 48, Hyper Palette, New feature failed'),
            ('new.ahk', 'TrayTip, Hyper, 新功能失败, 3'),
            ('new.py', "notify('New feature failed')"),
        ):
            with self.subTest(source=source):
                self.assertTrue(guard.source_errors(path, source, {'kind':'ui'}, labels))
        self.assertFalse(guard.source_errors('new.lua', "-- New feature label\nreturn {title=t('known')}", {'kind':'ui'}, labels))
        self.assertTrue(guard.source_errors('new.lua', 'hs.alert.show(message)', {'kind':'internal'}, labels))

    def test_separate_lua_catalog_requires_both_languages(self):
        for source in ("local messages={new={en='New feature'}}",
                       "local messages={new={zh='新功能'}}",
                       "local messages={new={en='Open {name}',zh='打开'}}"):
            self.assertTrue(guard.source_errors('catalog.lua', source, {'kind':'catalog'}, {}))
        self.assertFalse(guard.source_errors('catalog.lua', "local messages={new={en='Open {name}',zh='打开 {name}'}}", {'kind':'catalog'}, {}))

    def test_new_modules_cannot_silently_skip_audit(self):
        paths = guard.source_paths(guard.ROOT)
        with patch.object(guard, 'source_paths', return_value=paths | {'config/hammerspoon/private/modules/new.lua'}):
            with self.assertRaisesRegex(ValueError, 'new.lua: new module needs an i18n policy'):
                guard.validate_repository()

    def test_legacy_module_cannot_reenter_live_dependency_graph(self):
        read_text = Path.read_text

        def injected(path, *args, **kwargs):
            result = read_text(path, *args, **kwargs)
            if path.name == 'workbench.lua':
                result += "\nrequire('private/modules/app-launch-toggle')"
            return result

        with patch.object(Path, 'read_text', injected):
            with self.assertRaisesRegex(ValueError, 'legacy module is loaded'):
                guard.validate_repository()

    def test_repository_passes_audit(self):
        guard.validate_repository()
