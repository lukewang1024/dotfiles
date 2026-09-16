#!/usr/bin/env python3
"""Opt-in smoke test on isolated Xvfb displays, never the user's desktop.

Usage: python3 config/hyper/validate_x11.py i3|xfwm4 [--screenshot FILE]
Requires Xvfb, xterm, the chosen WM and the normal X11 adapter tools.
"""
import argparse
import json
import os
from pathlib import Path
import select
import subprocess
import time

from linux_desktop import create_desktop


def wait_for(check):
    deadline = time.monotonic()+8
    while time.monotonic()<deadline:
        try:
            result = check()
            if result:
                return result
        except (subprocess.CalledProcessError, ValueError, StopIteration):
            pass
        time.sleep(.1)
    raise AssertionError('Timed out waiting for X11 state')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('wm', choices=('i3','xfwm4'))
    parser.add_argument('--screenshot')
    args = parser.parse_args()
    processes = []
    def start(argv, env=None, **kw):
        process = subprocess.Popen(argv,env=env,stderr=subprocess.DEVNULL,**kw)
        processes.append(process)
        return process
    try:
        server = start(['Xvfb','-displayfd','1','-screen','0','1280x800x24','-nolisten','tcp'],stdout=subprocess.PIPE)
        if not select.select([server.stdout],[],[],8)[0]:
            raise AssertionError('Xvfb did not start')
        number = server.stdout.readline().decode().strip()
        if not number.isdigit():
            raise AssertionError('Xvfb returned no display')
        env = dict(os.environ,DISPLAY=':'+number,XDG_SESSION_TYPE='x11')
        for key in ('I3SOCK','SWAYSOCK','XAUTHORITY','SESSION_MANAGER'):
            env.pop(key,None)
        def call(*argv, **kw):
            return subprocess.run(argv,env=env,text=True,capture_output=True,check=True,timeout=5,**kw).stdout.strip()
        wm = ['i3','-c','/dev/null'] if args.wm=='i3' else ['xfwm4','--sm-client-disable']
        start(wm,env=env,stdout=subprocess.DEVNULL)
        wait_for(lambda: 'window id # 0x' in call('xprop','-root','_NET_SUPPORTING_WM_CHECK'))
        # Factory's live IPC probe must use this isolated display too.
        previous = os.environ.copy()
        os.environ.clear();os.environ.update(env)
        try:
            desktop = create_desktop(call,lambda *unused: None)
        finally:
            os.environ.clear();os.environ.update(previous)
        assert desktop.name==('i3' if args.wm=='i3' else 'ewmh'), desktop.name
        if desktop.name=='ewmh':
            call('wmctrl','-n','4')
        start(['xterm','-name','hyper-validation','-class','HyperValidation','-title','Hyper X11 backend validation','-e','sleep','120'],env=env,stdout=subprocess.DEVNULL)
        def window():
            return next(w for w in desktop.windows() if desktop.matches(w,{'instance':'hyper-validation','class':'HyperValidation'}))
        wid = wait_for(window)['id']
        # Keep workspace 1 alive: i3 removes empty workspaces and renumbers
        # their EWMH indices, unlike xfwm4's fixed workspace list.
        start(['xterm','-name','hyper-anchor','-class','HyperAnchor','-title','Validation workspace anchor','-e','sleep','120'],env=env,stdout=subprocess.DEVNULL)
        wait_for(lambda: any(desktop.matches(w,{'class':'HyperAnchor'}) for w in desktop.windows()))
        # xterm's character-cell increments otherwise constrain floating sizes.
        call('xprop','-id',str(wid),'-remove','WM_NORMAL_HINTS')
        desktop.move(wid,[100,100,600,400])
        wait_for(lambda: all(abs(a-b)<4 for a,b in zip(desktop.frame(wid),[100,100,600,400])))
        desktop.workspace(wid,2,True)
        wait_for(lambda: window()['desktop']==1)
        desktop.workspace(wid,1)
        desktop.activate(wid,'summon')
        wait_for(lambda: window()['desktop']==0 and desktop.active()==wid)
        desktop.workspace(wid,2,True)
        wait_for(lambda: window()['desktop']==1)
        desktop.workspace(wid,1)
        desktop.activate(wid,'focus')
        wait_for(lambda: int(call('xprop','-root','_NET_CURRENT_DESKTOP').split('=')[1])==1)
        saved = desktop.capture_app_window(window())
        desktop.minimize(wid)
        wait_for(lambda: desktop.hidden(window()))
        desktop.restore_app_window(saved)
        desktop.activate(wid,'focus')
        wait_for(lambda: not desktop.hidden(window()) and desktop.active()==wid)
        desktop.fullscreen(wid)
        wait_for(lambda: desktop.snapshot(wid).get('fullscreen'))
        desktop.restore(wid,saved['snapshot'])
        wait_for(lambda: not desktop.snapshot(wid).get('fullscreen'))
        if args.screenshot:
            path = Path(args.screenshot).resolve()
            path.parent.mkdir(parents=True,exist_ok=True)
            call('import','-window','root',str(path))
        print(json.dumps(dict(backend=desktop.name,display=env['DISPLAY'],result='PASS',
                              checks=['detect','instance/class','geometry','summon','focus','hide/restore','fullscreen'])))
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill();process.wait()


if __name__=='__main__':
    main()
