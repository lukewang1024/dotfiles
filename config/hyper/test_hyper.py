import importlib.machinery
import importlib.util
import json
from pathlib import Path
import sys
import copy
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate
from linux_desktop import EwmhDesktop
import linux_desktop

loader = importlib.machinery.SourceFileLoader('hyper_linux', str(generate.ROOT/'util/linux/hyper'))
spec = importlib.util.spec_from_loader(loader.name, loader)
linux = importlib.util.module_from_spec(spec)
loader.exec_module(linux)


class FullscreenStateTests(unittest.TestCase):
    def test_rust_dynamic_menu_and_leaf_dispatch_preserve_target(self):
        from unittest.mock import MagicMock
        import palette_bridge
        hyper=linux.Hyper.__new__(linux.Hyper)
        hyper.target=42
        hyper.desktop=MagicMock()
        actions=[]
        class Session:
            def __init__(self,value):
                self.rid=value['request_id'];self.value=value;self.child=None
            def command(self,command):
                self.child=command['request']
                assert command['type']=='push' and self.child['request_id']==self.rid
            def events(self):
                row=self.value['menus'][self.value['root']]['items'][0]
                assert row['navigate'] and row['keep_open']
                yield dict(type='action',action=row['id'],keep_open=True)
                row=self.child['menus'][self.child['root']]['items'][0]
                yield dict(type='action',action=row['id'])
            def close(self):pass
        def run(action):
            actions.append(action)
            if action=='menu.roles':hyper.choose([('','Example','launch.example')],'apps')
        hyper.run=run
        with patch.object(palette_bridge,'Session',Session):
            hyper.choose([('a','Roles','menu.roles')],'config',quick=True)
        self.assertEqual(actions,['menu.roles','launch.example'])
        hyper.desktop.focus.assert_called_once_with(42)
        self.assertIsNone(hyper.palette_session)

    def test_ewmh_snapshot_and_restore_keep_fullscreen_and_maximized(self):
        desktop=EwmhDesktop(lambda *a, **kw: linux.call(*a, **kw), linux.select_screen)
        with patch.object(desktop,'frame',return_value=[0,0,1200,900]), patch.object(linux,'call',return_value='_NET_WM_STATE_FULLSCREEN, _NET_WM_STATE_MAXIMIZED_VERT, _NET_WM_STATE_MAXIMIZED_HORZ'):
            saved=desktop.snapshot(42)
        self.assertTrue(saved['fullscreen'])
        self.assertTrue(saved['maximized'])
        rebased=linux.rebase_snapshot(saved,[0,0,1200,900],[-1600,0,1600,900])
        with patch.object(desktop,'move') as move, patch.object(linux,'call') as call:
            desktop.restore(42,rebased)
        move.assert_called_once_with(42,[-1600,0,1600,900])
        self.assertEqual([c.args[-1] for c in call.call_args_list],['add,maximized_vert,maximized_horz','add,fullscreen'])


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(generate.SOURCE.read_text())

    def test_number_row_has_function_roles_not_desktops(self):
        chords={(b['key'],bool(b.get('shift'))):b['action'] for b in generate.bindings(self.data)}
        expected=['menu.config','menu.windows','menu.apps','clipboard.history','capture.screenshot',
                  'capture.record','system.audioOutput','system.audioInput']
        for n,action in enumerate(expected):
            self.assertEqual(chords[str(n),False],action)
            self.assertNotIn((str(n),True),chords)
        self.assertFalse(any(action.startswith('desktop.') or action=='menu.desktop' for action in chords.values()))
        for key in ('8','9'):
            self.assertNotIn((key,False),chords)
            self.assertNotIn((key,True),chords)
        self.assertNotIn(('s',True),chords)
        self.assertNotIn('capture',self.data['menus'])
        self.assertEqual([row[2] for row in self.data['menus']['config']],['menu.roles','system.hyperKeys','system.reload','menu.clipboard','capture.screenshot','capture.record','system.displays','system.focus'])

    def test_linux_environment_routes_and_fallback(self):
        adapter=linux.Hyper.__new__(linux.Hyper)
        adapter.target=None
        adapter.desktop=object() # These actions must not require an active window.
        for action,command in {'audioOutput':['pavucontrol','--tab','3'],'audioInput':['pavucontrol','--tab','4'],
                               'displays':['xfce4-display-settings'],'focus':['xfce4-notifyd-config']}.items():
            with patch.object(linux.shutil,'which',return_value='/usr/bin/tool'),patch.object(adapter,'launch') as launch:
                adapter.run('system.'+action)
                launch.assert_called_once_with(command)
        with patch.object(linux.shutil,'which',side_effect=lambda cmd: cmd if cmd=='xfce4-settings-manager' else None),patch.object(adapter,'launch') as launch:
            adapter.run('system.displays')
            launch.assert_called_once_with(['xfce4-settings-manager'])

    def test_no_collisions_and_fast_ratio_keys(self):
        bindings = generate.bindings(self.data)
        chords = {(b['key'], bool(b.get('shift'))): b['action'] for b in bindings}
        self.assertNotIn(("'",False),chords)
        for key in ('`','return'):
            for shifted in (False,True):self.assertNotIn((key,shifted),chords)
        self.assertNotIn('window',self.data['menus'])
        self.assertEqual(chords[';', False], 'app.terminal')
        self.assertEqual(chords['h', True], 'mouse.left')
        self.assertEqual(chords['w', False], 'app.workChat')
        self.assertEqual(chords['c', False], 'app.dailyChat')
        self.assertEqual(chords['w',True],'launch.wechat')
        self.assertEqual(chords['a',False],'app.ai')
        self.assertEqual(chords['a',True],'launch.chatgpt')
        self.assertEqual(chords['d',True],'launch.doubao')
        self.assertEqual(chords['d',False],'app.docs')
        self.assertEqual(self.data['roles']['ai']['apps'][0],'chatgpt')
        self.assertEqual(chords['/',True],'menu.roles')
        self.assertEqual(self.data['roles']['workChat']['apps'][0],'feishu')
        self.assertEqual(self.data['roles']['dailyChat']['apps'][0],'wechat')
        self.assertNotIn('chat',self.data['roles'])
        self.assertNotIn(('q',False),chords)
        self.assertEqual(chords['f', True], 'launch.firefox')
        self.assertEqual(chords['c', True], 'launch.chrome')
        self.assertEqual(chords['e', True], 'launch.edge')
        self.assertEqual(chords['t', True], 'launch.sublime')
        self.assertEqual(chords['r', False], 'app.remote')
        self.assertEqual(chords['r', True], 'launch.reeder')
        self.assertEqual(chords['n', True], 'launch.nomachine')
        self.assertEqual(self.data['defaults']['mac']['remote'], 'windows-app')
        self.assertEqual(chords['e', False], 'app.editor')
        self.assertEqual(self.data['roles']['editor']['apps'][0],'sublime')
        self.assertEqual(chords['v',True],'launch.code')
        self.assertNotIn(('v',False),chords)
        self.assertEqual(list(chords.values()).count('clipboard.history'),1)
        self.assertEqual(chords[';', True], 'app.secondaryTerminal')
        for role in ('terminal','secondaryTerminal'):
            self.assertEqual(list(chords.values()).count('app.'+role),1)
        self.assertEqual(chords['up',False],'window.up')
        self.assertEqual(chords['down',False],'window.down')
        self.assertNotIn(('=',False),chords)
        self.assertEqual(self.data['defaults']['mac']['terminal'], 'iterm')
        self.assertNotIn(('t',False),chords)
        self.assertNotIn(('y',False),chords)
        self.assertFalse(any(action.startswith('role.') for action in chords.values()))
        self.assertNotIn('trae',self.data['apps'])
        self.assertEqual(chords['up', True], 'window.cycleTwoThirds')
        self.assertEqual(chords['down', True], 'window.cycleThirds')
        self.assertEqual(chords['left', True], 'screen.left')
        self.assertEqual(chords['right', True], 'screen.right')
        for action in ('screen.up','screen.down','menu.window','mode.resize'):
            self.assertNotIn(action,chords.values())
        self.assertEqual(len(chords), len(bindings))

    def test_window_menu_replaced_by_direct_actions(self):
        chords={(b['key'],bool(b.get('shift'))):b['action'] for b in generate.bindings(self.data)}
        for key,action in {'home':'window.center','end':'window.max','pageup':'window.top','pagedown':'window.bottom',
                           '[':'resize.left',']':'resize.right'}.items():
            self.assertEqual(chords[key,False],action)
        for key,action in {'home':'focus.left','end':'focus.right','pageup':'focus.up','pagedown':'focus.down',
                           'space':'window.fullscreen','[':'resize.up',']':'resize.down'}.items():
            self.assertEqual(chords[key,True],action)
        self.assertEqual(self.data['layoutCycles']['cycleTwoThirds'],['twoThirds','lastTwoThirds'])
        self.assertEqual(self.data['layoutCycles']['cycleThirds'],['lastThird','middleThird','firstThird'])
        for name,cycle in self.data['layoutCycles'].items():
            invalid=copy.deepcopy(self.data);invalid['layoutCycles'][name]=cycle+['unknown']
            with self.assertRaises(ValueError):generate.bindings(invalid)
        output=generate.outputs(self.data)['config/hyper/i3.conf']
        self.assertIn('Mod3+Shift+Up exec --no-startup-id hyper window.cycleTwoThirds',output)
        self.assertIn('Mod3+Shift+Down exec --no-startup-id hyper window.cycleThirds',output)
        self.assertIn('Mod3+Prior exec --no-startup-id hyper window.top',output)
        self.assertIn('Mod3+Shift+bracketright exec --no-startup-id hyper resize.down',output)
        self.assertNotIn('hyper menu.window\n',output)

    def test_every_default_exists_on_its_platform(self):
        for platform in ('mac', 'windows', 'linux'):
            for role, spec in self.data['roles'].items():
                app = self.data['defaults'].get(platform, {}).get(role, spec['apps'][0])
                self.assertIn(platform, self.data['apps'][app], (platform, role))

    def test_layouts_fit_workarea(self):
        for name, (x, y, w, h) in self.data['layouts'].items():
            self.assertTrue(0 <= x < 1 and 0 <= y < 1, name)
            self.assertTrue(w > 0 and h > 0 and x+w <= 1.000001 and y+h <= 1.000001, name)

    def test_ahk_v1_encoding_and_expression_limits(self):
        output = generate.outputs(self.data)['config/autohotkey/lib/hyper-generated.ahk']
        self.assertTrue(output.startswith('\ufeff'))
        self.assertLess(max(map(len, output.splitlines())), 1000)
        self.assertIn('data["apps"]["kitty"]["title"] := "kitty"', output)
        adapter = (generate.ROOT / 'config/autohotkey/lib/hyper.ahk').read_bytes()
        self.assertTrue(adapter.startswith(b'\xef\xbb\xbf'))

    def test_generated_input_does_not_spawn_python(self):
        output = generate.outputs(self.data)['config/hyper/i3.conf']
        self.assertIn('Mod3+Shift+h exec --no-startup-id xdotool mousemove_relative -- -10 0', output)
        self.assertNotIn('hyper select.', output)
        i3=generate.outputs(self.data)['config/i3/config']
        self.assertNotIn('include ~/.config/hyper/i3.conf',i3)
        self.assertEqual(i3.count('# BEGIN GENERATED HYPER'),1)
        self.assertEqual(i3.count('# END GENERATED HYPER'),1)
        self.assertEqual(i3.count('bindsym --release Mod3+0 exec --no-startup-id hyper menu.config'),1)

    def test_all_actions_have_known_families(self):
        supported = {'edit','select','mouse','resize','launch','window','screen','focus','menu','mode','capture','clipboard','system','remote','desktop','app','role'}
        actions = [b['action'] for b in generate.bindings(self.data)]
        actions += [row[2] for rows in self.data['menus'].values() for row in rows]
        for action in actions:
            self.assertIn(action.split('.')[0], supported)


class GeometryTests(unittest.TestCase):
    def test_xfce_outer_frame_uses_client_absolute_coordinates(self):
        desktop = EwmhDesktop(lambda *a, **kw: linux.call(*a, **kw), linux.select_screen)
        with patch.object(linux, 'call', side_effect=[
            'Absolute upper-left X: 3\nAbsolute upper-left Y: 60\nWidth: 954\nHeight: 968',
            '_NET_FRAME_EXTENTS(CARDINAL) = 3, 3, 29, 3',
        ]):
            self.assertEqual(desktop.frame(42), [0, 31, 960, 1000])

    def test_ewmh_move_excludes_decorations_and_waits_for_settle(self):
        desktop = EwmhDesktop(lambda *a, **kw: linux.call(*a, **kw), linux.select_screen)
        with patch.object(linux, 'call') as call, \
             patch.object(desktop, 'extents', return_value=[3,3,29,3]), \
             patch.object(desktop, 'frame', side_effect=[[100,100,800,600],[0,31,960,1000]]), \
             patch.object(linux_desktop.time, 'sleep') as sleep:
            desktop.move(42, [0,31,960,1000])
            call.assert_any_call('wmctrl','-ir','0x2a','-b','remove,fullscreen')
            call.assert_any_call('wmctrl','-ir','0x2a','-b','remove,maximized_vert,maximized_horz')
            call.assert_any_call('wmctrl','-ir','0x2a','-e','0,0,31,954,968')
            sleep.assert_called_once_with(.02)

    def test_portrait_layouts_and_cycles(self):
        data=json.loads(generate.SOURCE.read_text())
        portrait=[-900,30,900,1500]
        self.assertEqual(linux.place(portrait,linux.layout(data,'left',portrait)),[-900,30,900,750])
        self.assertEqual(linux.place(portrait,linux.layout(data,'right',portrait)),[-900,780,900,750])
        for name in ('top','bottom','topLeft','bottomRight'):
            self.assertEqual(linux.layout(data,name,portrait),data['layouts'][name])
        for area in ([0,0,1500,900],[0,0,900,900]):
            for name in data['adaptiveLayouts']:
                self.assertEqual(linux.layout(data,name,area),data['layouts'][name])
        for name,cycle in data['layoutCycles'].items():
            self.assertEqual(linux.cycle_layout(data,name,[0,0,200,200],portrait),cycle[0])
            for i,item in enumerate(cycle):
                frame=linux.place(portrait,linux.layout(data,item,portrait))
                self.assertEqual(frame[2],900)
                self.assertEqual(linux.cycle_layout(data,name,frame,portrait),cycle[(i+1)%len(cycle)])

    def test_layout_cycles_follow_actual_geometry_and_rounding(self):
        data=json.loads(generate.SOURCE.read_text())
        for area in ([0,30,1200,870],[-1729,-500,1729,971]):
            for name,cycle in data['layoutCycles'].items():
                self.assertEqual(linux.cycle_layout(data,name,[100,100,500,500],area),cycle[0])
                for i,layout in enumerate(cycle):
                    frame=linux.place(area,data['layouts'][layout])
                    self.assertEqual(linux.cycle_layout(data,name,frame,area),cycle[(i+1)%len(cycle)])
                    frame[0]+=1;frame[2]-=1
                    self.assertEqual(linux.cycle_layout(data,name,frame,area),cycle[(i+1)%len(cycle)])
                    frame[2]-=20
                    self.assertEqual(linux.cycle_layout(data,name,frame,area),cycle[0])

    def test_restore_geometry_follows_screen_preserving_flags(self):
        before={'frame':[100,100,600,400],'maximized':False,'floating':True}
        moved=linux.rebase_snapshot(before,[0,30,1200,870],[-1600,0,1600,900])
        self.assertEqual(moved['frame'],[-1467,72,800,414])
        self.assertFalse(moved['maximized'])
        self.assertTrue(moved['floating'])
        self.assertEqual(before['frame'],[100,100,600,400])

    def test_screen_wrap_and_other_axis_fallback(self):
        horizontal = [[-1000,0,1000,800],[0,0,1000,800],[1000,0,1000,800]]
        self.assertEqual(linux.select_screen(horizontal,2,'right',wrap=True),0)
        self.assertEqual(linux.select_screen(horizontal,0,'left',wrap=True),2)
        self.assertEqual(linux.select_screen(horizontal,1,'down',wrap=True),2)
        vertical = [[0,-800,1000,800],[0,0,1000,800]]
        self.assertEqual(linux.select_screen(vertical,0,'left',wrap=True),1)
        self.assertEqual(linux.select_screen(vertical,1,'right',wrap=True),0)
        self.assertEqual(linux.select_screen([horizontal[0]]*2,0,'right',wrap=True),1)
        self.assertIsNone(linux.select_screen(horizontal[:1],0,'right',wrap=True))

    def test_no_directional_wrap(self):
        screens = [[0,0,1920,1080],[-1280,100,1280,1024],[0,-900,1600,900]]
        self.assertEqual(linux.select_screen(screens,0,'left'),1)
        self.assertEqual(linux.select_screen(screens,0,'up'),2)
        self.assertIsNone(linux.select_screen(screens,0,'right'))
        self.assertIsNone(linux.select_screen(screens,0,'down'))

    def test_ratio_on_negative_origin_and_panel_offset(self):
        area = [-1920,30,1920,1050]
        left = linux.place(area,[0,0,2/3,1])
        right = linux.place(area,[2/3,0,1/3,1])
        self.assertEqual(left,[-1920,30,1280,1050])
        self.assertEqual(right,[-640,30,640,1050])
        self.assertEqual(left[0]+left[2],right[0])

    def test_wmctrl_window_parser(self):
        sample='0x04200002  2 3421 -10 40 1000 700 firefox.Firefox laptop A title with spaces\n'
        with patch.object(linux,'call',return_value=sample):
            win=EwmhDesktop(linux.call,linux.select_screen).windows()[0]
        self.assertEqual(win['id'],int('04200002',16))
        self.assertEqual(win['frame'],[-10,40,1000,700])
        self.assertEqual(win['title'],'A title with spaces')


class WindowStateTests(unittest.TestCase):
    def test_maximize_restore_snap_minimize_and_cross_screen(self):
        class Desktop:
            i3=False
            geometry=[100,100,600,400]
            minimized=0
            is_hidden=False
            def hidden(self,window):return self.is_hidden
            def active(self):return 1
            def windows(self):return [dict(id=1,pid=10,cls='Editor',frame=self.geometry[:])]
            def frame(self,wid):return self.geometry[:]
            def snapshot(self,wid):return dict(frame=self.geometry[:],maximized=False)
            def screens(self):return [[0,0,1200,900],[-1600,0,1600,900]]
            def current_screen(self,wid,screens):return 1 if self.geometry[0]<0 else 0
            def move(self,wid,rect):self.geometry=rect[:]
            def restore(self,wid,snapshot):self.geometry=snapshot['frame'][:]
            def minimize(self,wid):self.minimized+=1;self.is_hidden=True
            def focus(self,wid):self.is_hidden=False
        desktop=Desktop()
        with tempfile.TemporaryDirectory() as temp, patch.object(linux,'call',side_effect=lambda *args: '_NET_WM_STATE_HIDDEN' if desktop.is_hidden else ''):
            adapter=linux.Hyper.__new__(linux.Hyper)
            adapter.data=json.loads(generate.SOURCE.read_text())
            adapter.desktop=desktop;adapter.target=None
            adapter.state_dir=Path(temp);adapter.path=Path(temp)/'test.json'
            adapter.run('window.maximize');adapter.run('window.maximize')
            self.assertEqual(desktop.geometry,[0,0,1200,900])
            adapter.run('window.restoreDown')
            self.assertEqual(desktop.geometry,[100,100,600,400])
            self.assertEqual(desktop.minimized,0)
            adapter.run('window.restoreDown');self.assertEqual(desktop.minimized,1)
            adapter.run('window.left');adapter.run('window.left')
            adapter.run('window.maximize');adapter.run('window.restoreDown')
            self.assertEqual(desktop.geometry,[0,0,600,900])
            adapter.run('window.restoreDown')
            self.assertEqual(desktop.geometry,[100,100,600,400])
            adapter.run('window.maximize');adapter.run('screen.left');adapter.run('window.restoreDown')
            self.assertEqual(desktop.geometry,[-1467,100,800,400])
            adapter.run('window.left');desktop.geometry=[-1200,200,500,500]
            adapter.run('window.restoreDown');self.assertEqual(desktop.minimized,2)
            with patch.object(desktop,'active',side_effect=AssertionError('Restoring must work without a focused window')):
                adapter.run('window.up')
            self.assertFalse(desktop.is_hidden)
            self.assertEqual(desktop.geometry,[-1200,200,500,500])
            desktop.geometry=[100,100,600,400]
            adapter.run('window.left');adapter.run('window.up')
            self.assertEqual(desktop.geometry,[0,0,600,450])
            adapter.run('window.down');self.assertEqual(desktop.geometry,[0,0,600,900])
            adapter.run('window.down');self.assertEqual(desktop.geometry,[0,450,600,450])
            adapter.run('window.down');self.assertEqual(desktop.geometry,[100,100,600,400])
            adapter.run('window.right');adapter.run('window.up')
            self.assertEqual(desktop.geometry,[600,0,600,450])
            adapter.run('window.down');self.assertEqual(desktop.geometry,[600,0,600,900])
            adapter.run('window.down');self.assertEqual(desktop.geometry,[600,450,600,450])
            adapter.run('window.up');self.assertEqual(desktop.geometry,[600,0,600,900])
            desktop.geometry=[100,100,600,400]
            for name in ('twoThirds','lastTwoThirds','twoThirds'):
                adapter.run('window.cycleTwoThirds')
                self.assertEqual(desktop.geometry,linux.place(desktop.screens()[0],adapter.data['layouts'][name]))
            adapter.run('window.undo');self.assertEqual(desktop.geometry,[400,0,800,900])
            adapter.run('window.cycleTwoThirds');self.assertEqual(desktop.geometry,[0,0,800,900])
            for name in ('lastThird','middleThird','firstThird','lastThird'):
                adapter.run('window.cycleThirds')
                self.assertEqual(desktop.geometry,linux.place(desktop.screens()[0],adapter.data['layouts'][name]))
            desktop.geometry=[100,100,600,400]
            adapter.run('window.cycleThirds');self.assertEqual(desktop.geometry,[800,0,400,900])
            adapter.run('screen.left');adapter.run('window.cycleThirds')
            self.assertEqual(desktop.geometry,[-1067,0,533,900])
            adapter.run('window.restoreDown');self.assertEqual(desktop.geometry,[-1467,100,800,400])
            adapter.run('resize.right');self.assertEqual(desktop.geometry,[-1467,100,810,400])
            adapter.run('resize.down');self.assertEqual(desktop.geometry,[-1467,100,810,410])
            with patch.object(desktop,'screens',return_value=[[0,0,900,1500]]):
                desktop.geometry=[100,100,500,400]
                adapter.run('window.left');self.assertEqual(desktop.geometry,[0,0,900,750])
                adapter.run('window.up');self.assertEqual(desktop.geometry,[0,0,900,1500])
                adapter.run('window.down');self.assertEqual(desktop.geometry,[0,0,900,750])
                adapter.run('window.right');self.assertEqual(desktop.geometry,[0,750,900,750])
                adapter.run('window.cycleTwoThirds');self.assertEqual(desktop.geometry,[0,0,900,1000])
                adapter.run('window.cycleTwoThirds');self.assertEqual(desktop.geometry,[0,500,900,1000])
                adapter.run('window.cycleThirds');self.assertEqual(desktop.geometry,[0,1000,900,500])
                adapter.run('window.cycleThirds');self.assertEqual(desktop.geometry,[0,500,900,500])
                adapter.run('window.cycleThirds');self.assertEqual(desktop.geometry,[0,0,900,500])
                adapter.run('window.undo');self.assertEqual(desktop.geometry,[0,500,900,500])


class ToggleTests(unittest.TestCase):
    def test_ai_web_fallback_launches_without_matching_or_hiding_browser(self):
        adapter=linux.Hyper.__new__(linux.Hyper)
        adapter.data=json.loads(generate.SOURCE.read_text())
        adapter.desktop=EwmhDesktop(linux.call,linux.select_screen)
        with patch.object(adapter,'launch') as launch:
            adapter.toggle('chatgpt')
            launch.assert_called_once_with(['xdg-open','https://chatgpt.com/'])
        # No desktop adapter is needed for a web-only target.

    def test_only_newly_hidden_windows_restore_and_no_titles_persist(self):
        class Desktop(EwmhDesktop):
            active_id=1
            restored=[]
            def active(self):return self.active_id
            def windows(self):
                return [dict(id=n,pid=100+n,desktop=0,frame=[0,0,800,600],cls='firefox.Firefox',title='private title') for n in (1,2,3)]
            def snapshot(self,wid):return {'frame':[0,0,800,600],'maximized':wid==2}
            def restore(self,wid,saved):self.restored.append((wid,saved))
            def focus(self,wid):self.active_id=wid
        calls=[]
        def command(*args,**kwargs):
            calls.append(args)
            if args[0]=='xprop':return '_NET_WM_STATE_HIDDEN' if args[2]=='3' else ''
            return ''
        with tempfile.TemporaryDirectory() as temp:
            adapter=linux.Hyper.__new__(linux.Hyper)
            adapter.data=json.loads(generate.SOURCE.read_text())
            adapter.desktop=Desktop(lambda *a, **kw: linux.call(*a, **kw), linux.select_screen);adapter.target=None
            adapter.state_dir=Path(temp);adapter.path=Path(temp)/'test.json'
            with patch.object(linux,'call',side_effect=command):
                adapter.toggle('firefox')
                minimized=[args[-1] for args in calls if args[:2]==('xdotool','windowminimize')]
                self.assertEqual(minimized,['1','2'])
                self.assertNotIn('private title',adapter.path.read_text())
                adapter.desktop.active_id=99
                adapter.toggle('firefox')
            self.assertEqual([wid for wid,_ in adapter.desktop.restored],[1,2])
            self.assertTrue(adapter.desktop.restored[1][1]['maximized'])
            self.assertEqual(adapter.desktop.active_id,1)


if __name__ == '__main__':
    unittest.main()
