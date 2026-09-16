import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import app_index
import generate
import roles
from test_hyper import linux


class RoleTests(unittest.TestCase):
    def test_legacy_chat_migrates_to_work_not_daily(self):
        original={'chat':'lark','browser':'chrome'}
        migrated=roles.migrate(original)
        self.assertEqual(migrated['workChat'],'lark')
        self.assertNotIn('dailyChat',migrated)
        self.assertNotIn('workChat',original)
        self.assertEqual(roles.migrate(dict(original,workChat='feishu'))['workChat'],'feishu')

    def test_atomic_preferences_preserve_other_keys_and_reject_corrupt_config(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'hyper/local.json'
            roles.save_default(path,'workChat','feishu')
            data={'defaults':{'browser':'chrome','chat':'slack','clipboardTarget':'keep'},'apps':{'custom':{'title':'Custom'}}}
            path.write_text(json.dumps(data))
            roles.save_default(path,'dailyChat','wechat')
            updated=json.loads(path.read_text())
            self.assertEqual(updated['defaults']['browser'],'chrome')
            self.assertEqual(updated['defaults']['clipboardTarget'],'keep')
            self.assertEqual(updated['apps'],data['apps'])
            self.assertEqual(updated['defaults']['dailyChat'],'wechat')
            self.assertEqual(path.stat().st_mode & 0o777,0o600)
            path.write_text('{bad config')
            with self.assertRaises(ValueError):roles.save_default(path,'dailyChat','telegram')
            self.assertEqual(path.read_text(),'{bad config')

    def test_linux_configuration_routes_apply_without_launching_and_survive_reload(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(linux.os.environ,{'XDG_CONFIG_HOME':temp,'XDG_STATE_HOME':temp}), patch.object(linux,'create_desktop'), patch.object(linux,'notify'):
            adapter=linux.Hyper()
            self.assertEqual(adapter.role_app('workChat'),'feishu')
            self.assertEqual(adapter.role_app('dailyChat'),'wechat')
            self.assertEqual(len(adapter.role_rows()),len(adapter.data['roles']))
            with patch.object(adapter,'choose') as choose:
                adapter.run('menu.roles')
                self.assertEqual(choose.call_args.args[1],'roles')
                with patch.object(linux,'installed',return_value=[]):adapter.run('role.workChat')
                self.assertEqual(choose.call_args.args[1],'roleApps')
            with patch.object(adapter,'toggle') as toggle:
                adapter.run('setrole.workChat.slack')
                toggle.assert_not_called()
                adapter.run('app.workChat');toggle.assert_called_once_with('slack')
            self.assertEqual(linux.Hyper().role_app('workChat'),'slack')
            adapter.run('resetrole.workChat');self.assertEqual(adapter.role_app('workChat'),'feishu')
            with self.assertRaises(RuntimeError):adapter.set_role('workChat','not-configured')

    def test_discovered_linux_roles_use_window_identity_only_when_declared(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(linux.os.environ,{'XDG_CONFIG_HOME':temp,'XDG_STATE_HOME':temp}), patch.object(linux,'create_desktop'), patch.object(linux,'notify'):
            path=Path(temp)/'custom.editor.desktop'
            path.write_text('[Desktop Entry]\nType=Application\nName=Custom\nExec=custom %U\nStartupWMClass=ActualEditor\n')
            adapter=linux.Hyper();choice='installed.'+str(path)
            adapter.set_role('editor',choice)
            with patch.object(adapter,'toggle') as toggle:
                adapter.run('app.editor');toggle.assert_called_once_with(choice)
            self.assertEqual(adapter.data['apps'][choice]['linux'],{'class':'ActualEditor','argv':['gio','launch',str(path)]})
            self.assertEqual(linux.Hyper().role_app('editor'),choice)
            path.write_text('[Desktop Entry]\nType=Application\nName=Custom\nExec=custom %U\n')
            self.assertNotIn('class',app_index.linux_spec(path))

    def test_all_roles_have_shortcuts_and_bilingual_labels(self):
        from localize import catalog
        data=json.loads(generate.SOURCE.read_text());labels=catalog(data)
        for role in data['roles']:
            self.assertTrue(roles.shortcuts(data,role))
            for lang in ('en','zh'):self.assertIn('role.'+role,labels[lang])
