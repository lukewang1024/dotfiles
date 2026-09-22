#!/usr/bin/env python3
"""Seed writable Codex profiles and detach legacy dotfiles symlinks."""
import os
from pathlib import Path
import tempfile
import tomllib


def apply_profiles(templates, codex_home):
    codex_home.mkdir(parents=True, exist_ok=True)
    for name in ('team.config.toml', 'team-budget.config.toml'):
        source = templates / name
        target = codex_home / name
        if target.is_symlink():
            if target.resolve() != source.resolve():
                raise RuntimeError(f'Refusing unrelated profile symlink: {target}')
            # Snapshot everything, including trust written through the old link.
            content = target.read_bytes()
        elif target.exists():
            continue  # Runtime settings belong to this machine, not bootstrap.
        else:
            content = source.read_bytes()
        tomllib.loads(content.decode('utf-8'))
        fd, temporary = tempfile.mkstemp(prefix=name + '.', dir=codex_home)
        try:
            with os.fdopen(fd, 'wb') as stream:
                stream.write(content)
            os.replace(temporary, target)  # Replace the link, never its source.
        finally:
            Path(temporary).unlink(missing_ok=True)
        print(f'Codex local profile ready: {target}')


if __name__ == '__main__':
    apply_profiles(Path(__file__).resolve().parents[2] / 'config/agent',
                   Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex'))))
