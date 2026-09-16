#!/usr/bin/env python3
"""Release old Rectangle Hyper bindings, backing up only the affected keys."""
import argparse
import datetime
import json
import os
from pathlib import Path
import plistlib
import subprocess

DOMAIN = 'com.knollsoft.Rectangle'


def run(*args, check=True):
    return subprocess.run(args, check=check, capture_output=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    exported = run('defaults', 'export', DOMAIN, '-', check=False)
    if exported.returncode:
        print('Rectangle preferences not found; nothing to migrate')
        return
    preferences = plistlib.loads(exported.stdout)
    selected = {key: value for key, value in preferences.items()
                if isinstance(value, dict) and value.get('modifierFlags') in (1835008, 1966080)}
    print('Rectangle Hyper bindings: ' + (', '.join(sorted(selected)) or 'none'))
    if not args.apply or not selected:
        return
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'hyper'
    state.mkdir(parents=True, exist_ok=True)
    backup = state / ('rectangle-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.json')
    backup.write_text(json.dumps(selected, indent=2)+'\n')
    running = run('pgrep', '-x', 'Rectangle', check=False).returncode == 0
    if running:
        run('osascript', '-e', 'tell application "Rectangle" to quit')
    try:
        for key in selected:
            run('defaults', 'delete', DOMAIN, key)
    finally:
        if running:
            run('open', '-g', '-b', DOMAIN)
    print('Backup: ' + str(backup))
    print('Restore individual entries with: defaults write com.knollsoft.Rectangle KEY -dict keyCode -int CODE modifierFlags -int FLAGS')


if __name__ == '__main__':
    main()
