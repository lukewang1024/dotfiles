#!/usr/bin/env python3
"""Remove known ignored Codex settings while preserving local TOML formatting."""
import copy
from pathlib import Path
import sys
import tomllib


def single_path(value):
    path = []
    while isinstance(value, dict) and len(value) == 1:
        key, value = next(iter(value.items()))
        path.append(key)
    return tuple(path)


def clean_config(text):
    expected = copy.deepcopy(tomllib.loads(text))
    for profile in expected.get('profiles', {}).values():
        profile.pop('review_model', None)
    for project in expected.get('projects', {}).values():
        project.pop('sandbox_mode', None)

    output = []
    section = ()
    statement = ''
    for line in text.splitlines(keepends=True):
        if not statement and (not line.strip() or line.lstrip().startswith('#')):
            output.append(line)
            continue
        statement += line
        try:
            parsed = tomllib.loads(statement)
        except tomllib.TOMLDecodeError:
            continue  # Keep multiline values together, including apparent headers.
        if statement.lstrip().startswith('['):
            section = single_path(parsed)
            output.append(statement)
        else:
            path = section + single_path(parsed)
            ignored = (len(path) == 3 and
                       ((path[0] == 'profiles' and path[2] == 'review_model') or
                        (path[0] == 'projects' and path[2] == 'sandbox_mode')))
            if not ignored:
                output.append(statement)
        statement = ''
    if statement:
        raise ValueError('Cannot safely parse Codex config statements')
    cleaned = ''.join(output)
    if tomllib.loads(cleaned) != expected:
        raise ValueError('Cannot safely remove ignored Codex settings in this TOML layout')
    return cleaned


if __name__ == '__main__':
    path = Path(sys.argv[1])
    content = path.read_bytes().decode('utf-8')
    cleaned = clean_config(content)
    if cleaned != content:
        path.write_bytes(cleaned.encode('utf-8'))
        print('Codex ignored profile review_model and project sandbox_mode settings removed')
