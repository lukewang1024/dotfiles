"""Machine-local role preferences. Preserve unrelated settings on every write."""
import fcntl
import json
import os
from pathlib import Path
import tempfile


def migrate(defaults):
    result=dict(defaults)
    if 'chat' in result and 'workChat' not in result:
        result['workChat']=result['chat']
    return result


def save_default(path, role, choice):
    path=Path(path)
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    with path.with_suffix('.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        data=json.loads(path.read_text()) if path.exists() else {}
        data.setdefault('defaults',{})[role]=choice
        fd,temporary=tempfile.mkstemp(dir=path.parent)
        try:
            with os.fdopen(fd,'w') as out:json.dump(data,out,ensure_ascii=False,indent=2)
            os.replace(temporary,path)
        finally:
            if os.path.exists(temporary):os.unlink(temporary)


def shortcuts(data, role):
    from generate import bindings
    return ' / '.join('H+'+('Shift+' if b.get('shift') else '')+b['key']
                      for b in bindings(data) if b['action']=='app.'+role)
