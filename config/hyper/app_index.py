"""Installed application discovery. Cached data only; never executes app metadata."""
import argparse
import configparser
import json
import os
from pathlib import Path
import plistlib
import shutil
import sys
import tempfile
import time

TTL = 600


def roots(platform):
    if platform == 'mac':
        return [Path('/Applications'), Path('/System/Applications'), Path.home()/'Applications']
    data = Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share')))
    directories = os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')
    return [data/'applications'] + [Path(p)/'applications' for p in directories if p]


def scan_mac(directories):
    apps = []
    seen = set()
    for root in directories:
        for directory, dirs, _ in os.walk(root):
            for name in list(dirs):
                if not name.endswith('.app'):
                    continue
                dirs.remove(name)  # Do not expose nested helpers inside bundles.
                path = Path(directory)/name
                try:
                    with (path/'Contents/Info.plist').open('rb') as file:
                        info = plistlib.load(file)
                except (OSError, ValueError, plistlib.InvalidFileException):
                    continue
                if info.get('LSUIElement') or info.get('LSBackgroundOnly'):
                    continue
                identity = str(path.resolve())
                if identity in seen:
                    continue
                seen.add(identity)
                apps.append(dict(title=info.get('CFBundleDisplayName') or info.get('CFBundleName') or name[:-4],
                                 path=str(path), bundle=info.get('CFBundleIdentifier', '')))
    return sorted(apps, key=lambda app: app['title'].casefold())


def scan_linux(directories):
    apps, seen = [], set()
    desktops = set(os.environ.get('XDG_CURRENT_DESKTOP', '').split(':')) - {''}
    locale = os.environ.get('LC_MESSAGES') or os.environ.get('LANG', '')
    locale = locale.split('.')[0]
    for root in directories:
        for path in sorted(root.rglob('*.desktop')):
            desktop_id = str(path.relative_to(root)).replace('/', '-')
            if desktop_id in seen:
                continue
            seen.add(desktop_id)  # User overrides, including Hidden=true, win.
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            parser.optionxform = str
            try:
                parser.read(path, encoding='utf-8')
                entry = parser['Desktop Entry']
                if entry.get('Type') != 'Application' or entry.getboolean('Hidden', False) or entry.getboolean('NoDisplay', False):
                    continue
                only = set(entry.get('OnlyShowIn', '').split(';')) - {''}
                excluded = set(entry.get('NotShowIn', '').split(';')) - {''}
                if (only and not desktops.intersection(only)) or desktops.intersection(excluded):
                    continue
                if entry.get('TryExec') and not shutil.which(entry['TryExec']):
                    continue
                if not entry.get('Exec') and not entry.getboolean('DBusActivatable', False):
                    continue
                title = entry.get(f'Name[{locale}]') or entry.get(f'Name[{locale.split("_")[0]}]') or entry.get('Name')
                if title:
                    apps.append(dict(title=title, path=str(path), desktop_id=desktop_id, wmclass=entry.get('StartupWMClass','')))
            except (OSError, ValueError, KeyError, configparser.Error):
                continue
    return sorted(apps, key=lambda app: app['title'].casefold())


def linux_spec(path):
    parser=configparser.ConfigParser(interpolation=None,strict=False)
    parser.optionxform=str
    with Path(path).open(encoding='utf-8') as file:parser.read_file(file)
    entry=parser['Desktop Entry']
    if entry.get('Type')!='Application' or entry.getboolean('Hidden',False):
        raise ValueError('Application no longer installed')
    result={'argv':['gio','launch',str(path)]}
    if entry.get('StartupWMClass'):result['class']=entry['StartupWMClass']
    return result


def cache_path(platform):
    base = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home()/'.cache')))
    return base/'hyper'/f'apps-{platform}.json'


def installed(platform, refresh=False, directories=None, cache=None):
    cache = cache or cache_path(platform)
    directories = roots(platform) if directories is None else directories
    signature = [str(path) for path in directories]
    if not refresh:
        try:
            saved = json.loads(cache.read_text())
            if isinstance(saved, dict) and isinstance(saved.get('apps'), list) and saved.get('roots') == signature and saved.get('version') == 1 and 0 <= time.time()-saved['time'] < TTL:
                return saved['apps']
        except (OSError, ValueError, KeyError, TypeError):
            pass
    apps = scan_mac(directories) if platform == 'mac' else scan_linux(directories)
    cache.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(dir=cache.parent)
    try:
        with os.fdopen(fd, 'w') as file:
            json.dump(dict(version=1, time=time.time(), roots=signature, apps=apps), file, ensure_ascii=False)
        os.replace(temporary, cache)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return apps


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=('mac', 'linux'), default='mac' if sys.platform == 'darwin' else 'linux')
    parser.add_argument('--refresh', action='store_true')
    args = parser.parse_args()
    print(json.dumps(installed(args.platform, args.refresh), ensure_ascii=False))
