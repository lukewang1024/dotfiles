"""Desktop resources live in LFS and are downloaded only when they are used."""
import hashlib
import json
from pathlib import Path

from .engine import Failure, Skip
from .tasks import install, task


def verify_rime_assets(repo):
    """Return the pointers still needing hydration; never replace local edits."""
    manifest = json.loads((repo / 'config/Rime/lfs-manifest.json').read_text())
    pending = []
    for item in manifest:
        name = item['path']
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts or relative.parts[:2] != ('config', 'Rime'):
            raise Failure('Invalid Rime resource manifest path')
        path = repo / relative
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(repo.resolve()):
            raise Failure('Missing or symlinked Rime resource: ' + name)
        with path.open('rb') as source:
            prefix = source.read(1024)
        if prefix.startswith(b'version https://git-lfs.github.com/spec/v1\n'):
            expected = ('version https://git-lfs.github.com/spec/v1\n'
                        f"oid sha256:{item['sha256']}\nsize {item['size']}\n").encode()
            if prefix != expected or path.stat().st_size != len(expected):
                raise Failure('Rime pointer does not match its manifest: ' + name)
            pending.append(name)
            continue
        digest = hashlib.sha256()
        with path.open('rb') as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b''):
                digest.update(chunk)
        if path.stat().st_size != item['size'] or digest.hexdigest() != item['sha256']:
            raise Failure('Rime resource differs from the manifest; keep your edits and review: ' + name)
    return pending


@task()
def rime_assets(c):
    if c.platform in ('ish', 'termux'):
        raise Skip('Rime desktop resources are not needed on this platform')
    if not c.dry_run and not verify_rime_assets(c.repo):
        c.note('Rime resources already present; SHA256 verified')
        return
    if not c.dry_run and not (c.repo / '.git').exists():
        raise Failure('Rime resources require a Git checkout; clone the repository instead of a source archive')
    if not c.exists('git-lfs'):
        manager = {'macos': 'brew', 'windows': 'scoop', 'debian': 'apt', 'arch': 'pacman'}.get(c.platform)
        if manager is None:
            raise Failure('Install git-lfs, then rerun ./init run maintenance rime_assets')
        install(c, manager, ['git-lfs'])
        c.refresh_path()
    # Keep the existing tracked hooks. The tracked pre-push hook handles LFS.
    c.command('git', '-C', c.repo, 'lfs', 'install', '--local', '--skip-smudge', '--skip-repo')
    c.command('git', '-C', c.repo, 'lfs', 'pull', '--include=config/Rime/**', '--exclude=')
    if not c.dry_run and verify_rime_assets(c.repo):
        raise Failure('Rime resources remain as LFS pointers after download')
    c.note('Rime resources fetched and verified against their SHA256 manifest')
