"""X11 desktop backends. Shared application/layout policy lives in util/linux/hyper.

X11Desktop supplies window discovery and geometry; EwmhDesktop and I3Desktop
own window-manager operations. Commands are injectable for headless tests.
"""
import json
import re
import shutil
import subprocess
import time


class X11Desktop:
    def __init__(self, call, select_direction):
        self.call = call
        self.select_direction = select_direction

    def active(self):
        return int(self.call('xdotool', 'getactivewindow'))

    def windows(self):
        result = []
        for line in self.call('wmctrl', '-lpGx').splitlines():
            parts = line.split(None, 9)
            if len(parts) == 10:
                wid, desktop, pid, x, y, w, h, cls, host, title = parts
                if int(w)>0 and int(h)>0:
                    result.append(dict(id=int(wid,16), desktop=int(desktop), pid=int(pid),
                                       frame=list(map(int,[x,y,w,h])), cls=cls, title=title))
        return result

    def frame(self, wid):
        # xdotool/wmctrl can double-count the client offset under xfwm4.
        # Track the outer decorated frame, matching the layouts/work area.
        raw = self.call('xwininfo', '-id', str(wid))
        fields = [int(re.search(pattern + r':\s*(-?\d+)', raw).group(1))
                  for pattern in ('Absolute upper-left X', 'Absolute upper-left Y', 'Width', 'Height')]
        left, right, top, bottom = self.extents(wid)
        x, y, w, h = fields
        return [x-left, y-top, w+left+right, h+top+bottom]

    def extents(self, wid):
        raw = self.call('xprop', '-id', str(wid), '_NET_FRAME_EXTENTS')
        values = re.findall(r'\d+', raw.split('=', 1)[-1]) if '=' in raw else []
        return list(map(int, values[:4])) if len(values) >= 4 else [0, 0, 0, 0]

    def current_screen(self, wid, screens):
        x,y,w,h=self.frame(wid)
        return min(range(len(screens)),key=lambda i:(x+w/2-screens[i][0]-screens[i][2]/2)**2+(y+h/2-screens[i][1]-screens[i][3]/2)**2)

    def wait_frame(self, wid, rect):
        for _ in range(10):
            if all(abs(a-b)<3 for a,b in zip(self.frame(wid),rect)):
                break
            time.sleep(.02)

    def hidden(self, window):
        return window['desktop']<0 or '_NET_WM_STATE_HIDDEN' in self.call(
            'xprop','-id',str(window['id']),'_NET_WM_STATE')

    def capture_app_window(self, window):
        saved = {k:v for k,v in window.items() if k!='title'}
        saved['snapshot'] = self.snapshot(window['id'])
        return saved

    def restore_app_window(self, saved):
        self.reveal(saved)
        if saved.get('snapshot'):
            self.restore(saved['id'], saved['snapshot'])

    def app_spec(self, spec):
        result = dict(spec)
        result.update(spec.get(self.name, {}))
        if result.get('activation', 'focus') not in ('focus', 'summon'):
            raise ValueError('Application activation must be focus or summon')
        if not isinstance(result.get('hide_on_active', True), bool):
            raise ValueError('Application hide_on_active must be a boolean')
        return result

    def matches(self, window, spec):
        instance = window['cls'].split('.',1)[0]
        # Preserve old full WM_CLASS matching while adding exact instance filters.
        expected = spec.get('class')
        if expected and window['cls'].casefold().endswith('.'+expected.casefold()):
            instance = window['cls'][:-len(expected)-1]
        return ((not expected or window['cls'].casefold()==expected.casefold()
                 or window['cls'].casefold().endswith('.'+expected.casefold()))
                and (not spec.get('instance') or instance.casefold()==spec['instance'].casefold()))

    def activate(self, wid, strategy='focus'):
        if strategy=='summon':
            self.summon(wid)
        self.focus(wid)


class EwmhDesktop(X11Desktop):
    name = 'ewmh'
    reload_command = ('kbmod',)

    def screens(self):
        screens = []
        for line in self.call('xrandr','--listactivemonitors').splitlines()[1:]:
            match = re.search(r'(\d+)/\d+x(\d+)/\d+([+-]\d+)([+-]\d+)',line)
            if match:
                w,h,x,y=map(int,match.groups());screens.append([x,y,w,h])
        # EWMH workarea excludes desktop panels. Intersect each monitor with it.
        raw=self.call('xprop','-root','_NET_CURRENT_DESKTOP','_NET_WORKAREA')
        lines=raw.splitlines()
        if len(lines)>=2 and '=' in lines[0] and '=' in lines[1]:
            n=int(lines[0].split('=')[1]); values=list(map(int,re.findall(r'-?\d+',lines[1].split('=')[1])))
            if len(values)>=4*(n+1):
                x,y,w,h=values[n*4:n*4+4]
                screens=[[max(a,x),max(b,y),max(1,min(a+c,x+w)-max(a,x)),max(1,min(b+d,y+h)-max(b,y))] for a,b,c,d in screens]
        return screens

    def move(self, wid, rect):
        x,y,w,h = map(round,rect)
        # EWMH state messages carry at most two properties per request.
        self.call('wmctrl','-ir',hex(wid),'-b','remove,fullscreen')
        self.call('wmctrl','-ir',hex(wid),'-b','remove,maximized_vert,maximized_horz')
        left,right,top,bottom = self.extents(wid)
        self.call('wmctrl','-ir',hex(wid),'-e',f'0,{x},{y},{max(1,w-left-right)},{max(1,h-top-bottom)}')
        self.wait_frame(wid,[x,y,w,h])

    def focus(self, wid):
        self.call('wmctrl','-ia',hex(wid))

    def summon(self, wid):
        raw = self.call('xprop','-root','_NET_CURRENT_DESKTOP')
        desktop = int(raw.split('=',1)[1].strip())
        self.call('wmctrl','-ir',hex(wid),'-t',str(desktop))

    def minimize(self, wid):
        self.call('xdotool','windowminimize',str(wid))

    def reveal(self, saved):
        self.call('xdotool','windowmap',str(saved['id']))

    def snapshot(self, wid):
        state = self.call('xprop','-id',str(wid),'_NET_WM_STATE')
        return dict(frame=self.frame(wid),
                    maximized='_NET_WM_STATE_MAXIMIZED_VERT' in state and '_NET_WM_STATE_MAXIMIZED_HORZ' in state,
                    fullscreen='_NET_WM_STATE_FULLSCREEN' in state)

    def restore(self, wid, saved):
        self.move(wid,saved['frame'])
        if saved.get('maximized'):
            self.call('wmctrl','-ir',hex(wid),'-b','add,maximized_vert,maximized_horz')
        if saved.get('fullscreen'):
            self.call('wmctrl','-ir',hex(wid),'-b','add,fullscreen')

    def workspace(self, wid, number, move=False):
        if move:
            self.call('wmctrl','-ir',hex(wid),'-t',str(number-1))
        self.call('wmctrl','-s',str(number-1))

    def focus_direction(self, wid, direction):
        windows = self.windows()
        current = next(i for i,w in enumerate(windows) if w['id']==wid)
        target = self.select_direction([w['frame'] for w in windows],current,direction)
        if target is not None:
            self.focus(windows[target]['id'])

    def fullscreen(self, wid):
        self.call('wmctrl','-ir',hex(wid),'-b','toggle,fullscreen')


class I3Desktop(X11Desktop):
    name = 'i3'
    reload_command = ('i3-msg','reload')

    def active(self):
        def visit(node):
            if node.get('focused') and node.get('window'):
                return node['window']
            for child in node.get('nodes',[])+node.get('floating_nodes',[]):
                found = visit(child)
                if found is not None:
                    return found
        wid = visit(json.loads(self.call('i3-msg','-t','get_tree')))
        if wid is None:
            raise RuntimeError('No focused i3 window')
        return wid

    def window_node(self, wid):
        def visit(node, floating_rect=None):
            if node.get('type')=='floating_con':
                floating_rect = node.get('rect')
            if node.get('window')==wid:
                rect = node.get('rect') if node.get('fullscreen_mode') else floating_rect or node.get('rect')
                return dict(node, outer_rect=rect)
            for child in node.get('nodes',[])+node.get('floating_nodes',[]):
                found = visit(child, floating_rect)
                if found:
                    return found
        node = visit(json.loads(self.call('i3-msg','-t','get_tree')))
        if node is None:
            raise RuntimeError('Window is no longer managed by i3')
        return node

    def frame(self, wid):
        # i3 does not reliably expose _NET_FRAME_EXTENTS. Its container rect
        # includes borders/titlebar; X11 client geometry alone does not.
        rect = self.window_node(wid)['outer_rect']
        return [rect[k] for k in ('x','y','width','height')]

    def command(self, command):
        result = json.loads(self.call('i3-msg',command))
        if any(not item.get('success') for item in result):
            raise RuntimeError(str(result))

    def screens(self):
        return [[o['rect'][k] for k in ('x','y','width','height')]
                for o in json.loads(self.call('i3-msg','-t','get_workspaces')) if o['visible']]

    def move(self, wid, rect):
        x,y,w,h = map(round,rect)
        self.command(f'[id="{wid}"] fullscreen disable, floating enable, resize set {w} px {h} px, move position {x} px {y} px')
        self.wait_frame(wid,[x,y,w,h])

    def focus(self, wid):
        if any(w['id']==wid and w['desktop']<0 for w in self.windows()):
            self.command(f'[id="{wid}"] scratchpad show')
        self.command(f'[id="{wid}"] focus')

    def summon(self, wid):
        self.command(f'[id="{wid}"] move container to workspace current')

    def minimize(self, wid):
        self.command(f'[id="{wid}"] move scratchpad')

    def capture_app_window(self, window):
        saved = super().capture_app_window(window)
        # Keep the existing state-file workspace field for backwards compatibility.
        names = re.findall(r'"((?:[^"\\]|\\.)*)"',self.call('xprop','-root','_NET_DESKTOP_NAMES'))
        if 0<=window['desktop']<len(names):
            saved['workspace'] = names[window['desktop']]
        return saved

    def reveal(self, saved):
        if saved.get('workspace'):
            self.command(f'[id="{saved["id"]}"] move container to workspace {json.dumps(saved["workspace"])}')

    def hidden(self, window):
        return window['desktop']<0

    def snapshot(self, wid):
        result = {'frame':self.frame(wid)}
        node = self.window_node(wid)
        result.update(floating=node['floating'].endswith('_on'),fullscreen=node.get('fullscreen_mode',0))
        return result

    def restore(self, wid, saved):
        self.move(wid,saved['frame'])
        if not saved.get('floating',True):
            self.command(f'[id="{wid}"] floating disable')
        if saved.get('fullscreen'):
            self.command(f'[id="{wid}"] fullscreen enable')

    def workspace(self, wid, number, move=False):
        if move:
            self.command(f'[id="{wid}"] move container to workspace number {number}')
        self.command(f'workspace number {number}')

    def focus_direction(self, wid, direction):
        self.command(f'[id="{wid}"] focus {direction}')

    def fullscreen(self, wid):
        self.command(f'[id="{wid}"] fullscreen toggle')


def create_desktop(call, select_direction):
    """Select once by live IPC, not by executable installation alone."""
    if shutil.which('i3-msg'):
        try:
            if subprocess.run(['i3-msg','-t','get_version'],capture_output=True,timeout=1).returncode == 0:
                return I3Desktop(call, select_direction)
        except (OSError,subprocess.TimeoutExpired):
            pass
    return EwmhDesktop(call, select_direction)
