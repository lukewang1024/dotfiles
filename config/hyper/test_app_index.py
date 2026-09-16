from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

import app_index


class AppIndexTests(unittest.TestCase):
    def test_mac_discovers_actual_names_and_skips_nested_helpers(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            def bundle(path,info):
                path.mkdir(parents=True)
                (path/'Info.plist').write_bytes(plistlib.dumps(info))
            bundle(root/'Trae Real Name.app/Contents',{'CFBundleName':'Trae Real Name','CFBundleIdentifier':'actual.vendor.id'})
            bundle(root/'Trae Real Name.app/Contents/Helper.app/Contents',{'CFBundleName':'Nested helper'})
            bundle(root/'Agent.app/Contents',{'CFBundleName':'Background','LSUIElement':True})
            rows=app_index.scan_mac([root])
            self.assertEqual([row['title'] for row in rows],['Trae Real Name'])
            self.assertEqual(rows[0]['bundle'],'actual.vendor.id')

    def test_linux_xdg_overrides_hidden_entries_and_localized_name(self):
        with tempfile.TemporaryDirectory() as temp:
            user,system=Path(temp)/'user',Path(temp)/'system'
            user.mkdir();system.mkdir()
            desktop='[Desktop Entry]\nType=Application\nName=Editor\nExec=editor %U\n'
            (system/'editor.desktop').write_text(desktop)
            (user/'editor.desktop').write_text(desktop+'Hidden=true\n')
            (system/'real.desktop').write_text(desktop+'Name[zh_CN]=编辑器\n')
            (system/'helper.desktop').write_text(desktop+'NoDisplay=true\n')
            (system/'other.desktop').write_text(desktop+'OnlyShowIn=GNOME;\n')
            with patch.dict(app_index.os.environ,{'LANG':'zh_CN.UTF-8','LC_MESSAGES':'','XDG_CURRENT_DESKTOP':'i3'}):
                rows=app_index.scan_linux([user,system])
            self.assertEqual([row['title'] for row in rows],['编辑器'])

    def test_cache_reuses_results_and_refresh_replaces_removed_apps(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);cache=root/'cache.json'
            sample=[dict(title='Editor',path='/Applications/Editor.app')]
            with patch.object(app_index,'scan_mac',return_value=sample) as scan:
                self.assertEqual(app_index.installed('mac',directories=[root],cache=cache),sample)
                self.assertEqual(app_index.installed('mac',directories=[root],cache=cache),sample)
                self.assertEqual(scan.call_count,1)
                scan.return_value=[]
                self.assertEqual(app_index.installed('mac',True,[root],cache),[])
                self.assertEqual(scan.call_count,2)
                cache.write_text('[]')
                self.assertEqual(app_index.installed('mac',directories=[root],cache=cache),[])
                self.assertEqual(scan.call_count,3)


if __name__=='__main__':
    unittest.main()
