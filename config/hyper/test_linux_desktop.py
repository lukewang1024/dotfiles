import contextlib
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock, patch

import linux_desktop as backend
from test_hyper import linux


class SelectionTests(unittest.TestCase):
    def test_live_i3_ipc_selects_i3(self):
        with patch.object(backend.shutil, 'which', return_value='/bin/i3-msg'), \
             patch.object(backend.subprocess, 'run', return_value=Mock(returncode=0)):
            self.assertIsInstance(backend.create_desktop(Mock(), Mock()), backend.I3Desktop)

    def test_installed_but_unreachable_i3_falls_back(self):
        for failure in (Mock(returncode=1), OSError('missing'), subprocess.TimeoutExpired('i3-msg', 1)):
            with self.subTest(failure=failure), patch.object(backend.shutil, 'which', return_value='/bin/i3-msg'), \
                 patch.object(backend.subprocess, 'run') as run:
                if isinstance(failure, Exception):
                    run.side_effect = failure
                else:
                    run.return_value = failure
                self.assertIsInstance(backend.create_desktop(Mock(), Mock()), backend.EwmhDesktop)

    def test_no_i3_binary_does_not_probe(self):
        with patch.object(backend.shutil, 'which', return_value=None), patch.object(backend.subprocess, 'run') as run:
            self.assertIsInstance(backend.create_desktop(Mock(), Mock()), backend.EwmhDesktop)
            run.assert_not_called()


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.call = Mock(return_value='[{"success":true}]')
        self.i3 = backend.I3Desktop(self.call, linux.select_screen)
        self.ewmh = backend.EwmhDesktop(self.call, linux.select_screen)

    def test_i3_commands_and_errors(self):
        self.i3.minimize(42)
        self.i3.fullscreen(42)
        self.i3.focus_direction(42, 'left')
        self.i3.workspace(42, 3, True)
        self.assertEqual([c[0][1] for c in self.call.call_args_list], [
            '[id="42"] move scratchpad', '[id="42"] fullscreen toggle',
            '[id="42"] focus left', '[id="42"] move container to workspace number 3',
            'workspace number 3'])
        self.call.return_value = '[{"success":false,"error":"bad command"}]'
        with self.assertRaises(RuntimeError):
            self.i3.minimize(42)

    def test_i3_snapshot_restore_retains_tiling_and_fullscreen(self):
        tree = {'nodes': [{'nodes': [], 'floating_nodes': [
            {'window':42, 'floating':'auto_off', 'fullscreen_mode':1}]}]}
        self.call.return_value = json.dumps(tree)
        with patch.object(self.i3, 'frame', return_value=[0,0,800,600]):
            saved = self.i3.snapshot(42)
        self.assertEqual(saved, dict(frame=[0,0,800,600], floating=False, fullscreen=1))
        with patch.object(self.i3, 'move') as move, patch.object(self.i3, 'command') as command:
            self.i3.restore(42, saved)
        move.assert_called_once_with(42, saved['frame'])
        self.assertEqual([c[0][0] for c in command.call_args_list], [
            '[id="42"] floating disable', '[id="42"] fullscreen enable'])

    def test_i3_geometry_and_visible_workareas(self):
        self.call.return_value = json.dumps({'nodes':[dict(window=42,rect=dict(x=100,y=100,width=600,height=400))]})
        self.assertEqual(self.i3.frame(42), [100,100,600,400])
        self.call.return_value = json.dumps({'floating_nodes':[
            dict(type='floating_con',rect=dict(x=100,y=100,width=600,height=400),nodes=[
                dict(window=42,rect=dict(x=100,y=118,width=600,height=382))])]})
        self.assertEqual(self.i3.frame(42), [100,100,600,400])
        with patch.object(self.i3, 'command') as command, patch.object(self.i3, 'wait_frame'):
            self.i3.move(42, [-800,30,800,600])
        command.assert_called_once_with('[id="42"] fullscreen disable, floating enable, resize set 800 px 600 px, move position -800 px 30 px')
        self.call.return_value = json.dumps([
            dict(visible=True, rect=dict(x=-800,y=30,width=800,height=600)),
            dict(visible=False, rect=dict(x=0,y=0,width=800,height=600))])
        self.assertEqual(self.i3.screens(), [[-800,30,800,600]])

    def test_i3_active_uses_tree_even_when_ewmh_focus_is_stale(self):
        self.call.return_value = json.dumps({'nodes':[], 'floating_nodes':[
            {'focused':False,'nodes':[{'window':42,'focused':True}]}]})
        self.assertEqual(self.i3.active(), 42)
        self.call.assert_called_once_with('i3-msg','-t','get_tree')
        self.call.return_value = '{}'
        with self.assertRaises(RuntimeError):
            self.i3.active()

    def test_scratchpad_focus_and_old_workspace_state_restore(self):
        with patch.object(self.i3, 'windows', return_value=[dict(id=42,desktop=-1)]), \
             patch.object(self.i3, 'command') as command:
            self.i3.focus(42)
        self.assertEqual([c[0][0] for c in command.call_args_list], [
            '[id="42"] scratchpad show', '[id="42"] focus'])
        saved = dict(id=42,workspace='2: code',snapshot={'frame':[0,0,800,600]})
        with patch.object(self.i3, 'command') as command, patch.object(self.i3, 'restore') as restore:
            self.i3.restore_app_window(saved)
        command.assert_called_once_with('[id="42"] move container to workspace "2: code"')
        restore.assert_called_once_with(42, saved['snapshot'])

    def test_i3_capture_omits_title_and_keeps_workspace(self):
        self.call.return_value = '_NET_DESKTOP_NAMES(UTF8_STRING) = "1", "2: code"'
        window = dict(id=42,desktop=1,title='private')
        with patch.object(self.i3, 'snapshot', return_value={'frame':[0,0,800,600]}):
            saved = self.i3.capture_app_window(window)
        self.assertEqual(saved['workspace'], '2: code')
        self.assertNotIn('title', saved)

    def test_summon_and_focus_are_distinct_on_both_backends(self):
        for desktop in (self.i3,self.ewmh):
            with self.subTest(backend=desktop.name), patch.object(desktop, 'summon') as summon, \
                 patch.object(desktop, 'focus') as focus:
                desktop.activate(42, 'focus')
                summon.assert_not_called()
                desktop.activate(42, 'summon')
                summon.assert_called_once_with(42)
                self.assertEqual(focus.call_count, 2)
        self.i3.summon(42)
        self.call.assert_called_with('i3-msg','[id="42"] move container to workspace current')
        self.call.return_value = '_NET_CURRENT_DESKTOP(CARDINAL) = 2'
        self.ewmh.summon(42)
        self.call.assert_called_with('wmctrl','-ir','0x2a','-t','2')

    def test_ewmh_window_operations_do_not_use_i3(self):
        self.ewmh.minimize(42)
        self.ewmh.reveal({'id':42})
        self.ewmh.fullscreen(42)
        self.ewmh.workspace(42, 3, True)
        self.assertEqual([c[0] for c in self.call.call_args_list], [
            ('xdotool','windowminimize','42'), ('xdotool','windowmap','42'),
            ('wmctrl','-ir','0x2a','-b','toggle,fullscreen'),
            ('wmctrl','-ir','0x2a','-t','2'), ('wmctrl','-s','2')])

    def test_exact_instance_and_class_matching(self):
        window = dict(cls='filemanagerA.Thunar')
        self.assertTrue(self.i3.matches(window, {'class':'thunar','instance':'filemanagerA'}))
        self.assertFalse(self.i3.matches(window, {'class':'Thunar','instance':'filemanagerB'}))
        self.assertTrue(self.i3.matches(window, {'instance':'filemanagerA'}))
        self.assertTrue(self.i3.matches(window, {'class':'filemanagerA.Thunar'}))
        self.assertFalse(self.i3.matches(window, {'class':'Thun'}))

    def test_app_overrides_are_scoped_and_validated(self):
        spec = dict(argv=['editor'], activation='focus', i3=dict(activation='summon',hide_on_active=False))
        self.assertEqual(self.i3.app_spec(spec)['activation'], 'summon')
        self.assertFalse(self.i3.app_spec(spec)['hide_on_active'])
        self.assertEqual(self.ewmh.app_spec(spec)['activation'], 'focus')
        self.assertEqual(spec['activation'], 'focus')
        for invalid in ({'activation':'oops'}, {'hide_on_active':'false'}):
            with self.assertRaises(ValueError):
                self.i3.app_spec(invalid)

    def test_prior_srun_apps_summon_only_under_i3(self):
        data = json.loads((Path(__file__).parent/'keys.json').read_text())
        for name in ('music','qqmusic','wechat','passwords'):
            spec = data['apps'][name]['linux']
            self.assertEqual(self.i3.app_spec(spec)['activation'], 'summon')
            self.assertEqual(self.ewmh.app_spec(spec).get('activation','focus'), 'focus')


class ApplicationPolicyTests(unittest.TestCase):
    def test_nohide_and_summon_policy_in_shared_dispatch(self):
        hyper = linux.Hyper.__new__(linux.Hyper)
        desktop = backend.I3Desktop(Mock(), linux.select_screen)
        hyper.desktop = desktop
        hyper.target = 42
        hyper.data = {'apps':{'editor':{'linux':dict(instance='editor',argv=['editor'],
                                                   activation='summon',hide_on_active=False)}}}
        state = {}
        @contextlib.contextmanager
        def saved_state():
            yield state
        hyper.state = saved_state
        with patch.object(desktop, 'windows', return_value=[dict(id=42,cls='editor.Editor')]), \
             patch.object(desktop, 'minimize') as minimize, patch.object(desktop, 'activate') as activate:
            hyper.toggle('editor')
            minimize.assert_not_called()
            activate.assert_not_called()
            hyper.target = 99
            hyper.toggle('editor')
            activate.assert_called_once_with(42,'summon')

    def test_shared_dispatch_has_no_i3_branches(self):
        source = (Path(__file__).resolve().parents[2]/'util/linux/hyper').read_text()
        self.assertNotIn('.i3', source)
        self.assertNotIn('i3-msg', source)


if __name__ == '__main__':
    unittest.main()
