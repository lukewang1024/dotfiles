"""Install a verified CI ZIP into XDG data; retain the previous installation."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import tempfile
import zipfile
import uuid

from palette_bridge import data_home, stop_host


def install(archive, target, commit, checksum):
    archive = Path(archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != checksum:
        raise ValueError('Archive SHA256 mismatch')
    root = data_home()
    root.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix='install-', dir=str(root)))
    try:
        with zipfile.ZipFile(str(archive)) as package:
            for entry in package.infolist():
                path = PurePosixPath(entry.filename)
                if path.is_absolute() or '..' in path.parts or '\\' in entry.filename or ':' in entry.filename:
                    raise ValueError('Unsafe archive path')
                package.extract(entry, str(staging))
                if not entry.is_dir():
                    (staging / entry.filename).chmod(0o755 if (entry.external_attr >> 16) & 0o111 else 0o644)
        manifests = list(staging.rglob('manifest.json'))
        if len(manifests) != 1:
            raise ValueError('Expected exactly one manifest')
        manifest = json.loads(manifests[0].read_text())
        if manifest.get('target') != target or manifest.get('commit') != commit or manifest.get('protocol') != 1:
            raise ValueError('Artifact identity/protocol mismatch: ' + repr(manifest))
        current = root / 'current'
        stop_host()
        previous = root / ('previous-' + uuid.uuid4().hex[:12])
        had_previous = current.exists()
        if had_previous:
            current.rename(previous)
        try:
            manifests[0].parent.rename(current)
        except OSError:
            if had_previous:
                previous.rename(current)
            raise
        return dict(path=str(current), sha256=checksum, manifest=manifest)
    finally:
        if staging.exists():
            shutil.rmtree(str(staging))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('archive')
    parser.add_argument('--target', required=True)
    parser.add_argument('--commit')
    parser.add_argument('--sha256')
    args = parser.parse_args()
    pinned = json.loads(Path(__file__).with_name('palette-build.json').read_text(encoding='utf-8'))
    if bool(args.commit) != bool(args.sha256):
        parser.error('Supply both --commit and --sha256, or neither to use the pinned build')
    print(json.dumps(install(args.archive, args.target, args.commit or pinned['commit'],
                             args.sha256 or pinned['sha256'][args.target]), indent=2))
