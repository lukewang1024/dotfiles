#!/usr/bin/env python3
"""Apply daily defaults from agent-team and archive obsolete writable profiles."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import tomllib


def replace_section_keys(text, section, values):
    lines = text.splitlines(keepends=True)
    output = []
    current = None
    inserted = False
    for line in lines:
        header = re.match(r'^\s*\[([^\[\]]+)\]\s*(?:#.*)?$', line)
        if header:
            if current == section and not inserted:
                output.extend(f'{key} = {json.dumps(value)}\n' for key, value in values.items())
                inserted = True
            current = header[1]
        if current == section and re.match(r'^\s*(' + '|'.join(re.escape(k) for k in values) + r')\s*=', line):
            continue
        output.append(line)
    if not inserted:
        if section and current != section:
            while output and not output[-1].strip():
                output.pop()
            if output and not output[-1].endswith('\n'):
                output[-1] += '\n'
            output.append(f'\n[{section}]\n')
        # Top-level keys must precede all tables.
        added = [f'{key} = {json.dumps(value)}\n' for key, value in values.items()]
        if section is None:
            output = added + output
        else:
            output.extend(added)
    return ''.join(output)


def apply_profiles(templates, codex_home, scene=None, archive=None):
    codex_home.mkdir(parents=True, exist_ok=True)
    if scene is None:
        plan = subprocess.run(['agent-team', 'start', 'codex', '--scene', 'daily', '--dry-run'],
                              check=True, capture_output=True, text=True)
        scene = json.loads(plan.stdout)['config']
    target = codex_home / 'config.toml'
    text = target.read_text() if target.exists() else ''
    tomllib.loads(text)
    text = replace_section_keys(text, None, {
        'model': scene['model'], 'model_reasoning_effort': scene['effort'],
        'plan_mode_reasoning_effort': scene['effort'],
        'service_tier': 'fast' if scene['fast'] else 'default',
    })
    text = replace_section_keys(text, 'agents', {'enabled': False})
    tomllib.loads(text)
    archive = archive or Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'agent-team/retired-profiles'
    retired = []
    for name in ('team.config.toml', 'team-budget.config.toml', 'team-expert.config.toml'):
        old = codex_home / name
        if not old.exists() and not old.is_symlink():
            continue
        # Preserve trust and local settings in an archive, never silently discard.
        data = old.read_bytes()
        tomllib.loads(data.decode())
        archive.mkdir(parents=True, exist_ok=True)
        backup = archive / name
        if backup.exists() and backup.read_bytes() != data:
            raise RuntimeError(f'Retired profile archive conflict: {backup}')
        backup.write_bytes(data)
        backup.chmod(0o600)
        retired.append(old)
    if not target.exists() or text != target.read_text():
        fd, temporary = tempfile.mkstemp(prefix='config.toml.', dir=codex_home)
        try:
            with os.fdopen(fd, 'w') as stream:
                stream.write(text)
            os.replace(temporary, target)
        finally:
            Path(temporary).unlink(missing_ok=True)
    for old in retired:
        old.unlink()
    print('Codex default scene ready: daily · Single')


if __name__ == '__main__':
    apply_profiles(Path(__file__).resolve().parents[2] / 'config/agent',
                   Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex'))))
