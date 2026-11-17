#!/usr/bin/env python3
"""Preserve Workbench checkout changes in a separate worktree before updating."""

import argparse
import hashlib
import os
from pathlib import Path
import stat
import subprocess
import sys
import time
import uuid


class MigrationError(Exception):
    pass


def git(repo, *args, check=True, env=None):
    result = subprocess.run(
        ['git', '-C', str(repo), *args], stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, env=env,
    )
    if check and result.returncode:
        detail = result.stderr.decode(errors='replace').strip()
        raise MigrationError(detail or f'git {args[0]} failed')
    return result


def paths(data):
    return [item for item in data.split(b'\0') if item]


def hash_file(path):
    info = path.lstat()
    if stat.S_ISLNK(info.st_mode):
        return ('symlink', os.fsencode(os.readlink(path)))
    if not stat.S_ISREG(info.st_mode):
        raise MigrationError(f'unsupported untracked path: {path}')
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return ('file', stat.S_IMODE(info.st_mode), digest.digest())


def snapshot(repo):
    status = git(repo, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout
    staged = git(repo, 'diff', '--cached', '--no-ext-diff', '--no-renames',
                 '--binary', '--full-index').stdout
    unstaged = git(repo, 'diff', '--no-ext-diff', '--no-renames',
                   '--binary', '--full-index').stdout
    untracked = paths(git(repo, 'ls-files', '--others', '--exclude-standard', '-z').stdout)
    signatures = [(name, hash_file(repo / os.fsdecode(name))) for name in sorted(untracked)]
    return status, staged, unstaged, signatures


def reject_unsafe_state(repo):
    if git(repo, 'ls-files', '--unmerged', '-z').stdout:
        raise MigrationError('unmerged files must be resolved before updating')
    flags = paths(git(repo, 'ls-files', '-v', '-z').stdout)
    if any(item[:1] == b'S' or item[:1].islower() for item in flags):
        raise MigrationError('skip-worktree or assume-unchanged files prevent a safe migration')
    status = paths(git(repo, 'status', '--porcelain=v2', '-z', '--untracked-files=all').stdout)
    if any(item.startswith((b'1 ', b'2 ')) and item.split(b' ', 4)[2].startswith(b'S')
           for item in status):
        raise MigrationError('modified submodules must be preserved separately before updating')


def ancestors(name):
    parts = name.split(b'/')
    return {b'/'.join(parts[:i]) for i in range(1, len(parts))}


def reject_overwrites(repo, target, include_untracked=False):
    args = ['ls-files', '--others', '--exclude-standard', '-z']
    if not include_untracked:
        args.insert(2, '--ignored')
    existing = {name.rstrip(b'/') for name in paths(git(repo, *args).stdout)}
    targets = set(paths(git(repo, 'ls-tree', '-r', '--name-only', '-z', target).stdout))
    existing_parents = set().union(*(ancestors(name.rstrip(b'/')) for name in existing)) if existing else set()
    target_parents = set().union(*(ancestors(name) for name in targets)) if targets else set()
    conflicts = (existing & targets) | (existing & target_parents) | (targets & existing_parents)
    if conflicts:
        name = os.fsdecode(sorted(conflicts)[0])
        kind = 'untracked' if include_untracked else 'ignored'
        raise MigrationError(f'{kind} path would be overwritten by the update: {name}')


def stash_ref(repo):
    result = git(repo, 'rev-parse', '--verify', 'refs/stash', check=False)
    return result.stdout.strip() if result.returncode == 0 else b''


def find_stash(repo, marker):
    listing = git(repo, 'stash', 'list', '--format=%H%x09%gs').stdout
    for line in listing.splitlines():
        commit, separator, subject = line.partition(b'\t')
        if separator and marker.encode() in subject:
            return commit
    return b''


def verify_aligned(repo, target_head):
    actual_head = git(repo, 'rev-parse', 'HEAD').stdout.decode().strip()
    status = git(repo, 'status', '--porcelain=v1', '-z', '--untracked-files=all').stdout
    if actual_head != target_head or status:
        raise MigrationError('installation checkout changed while updating; refusing to install a mixed version')


def create_backup(repo, root, old_head):
    root.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime('%Y%m%d-%H%M%S')
    for _ in range(10):
        suffix = uuid.uuid4().hex[:8]
        branch = f'workbench-recovered/{stamp}-{suffix}'
        destination = root / f'{stamp}-{suffix}'
        if not destination.exists() and git(repo, 'show-ref', '--verify', '--quiet',
                                            f'refs/heads/{branch}', check=False).returncode:
            git(repo, 'worktree', 'add', '-b', branch, str(destination), old_head)
            return destination, branch
    raise MigrationError('could not allocate a unique recovery worktree')


def migrate(repo, target, root, preserve_only=False):
    repo = repo.resolve()
    reject_unsafe_state(repo)
    reject_overwrites(repo, target)
    old_head = git(repo, 'rev-parse', 'HEAD').stdout.decode().strip()
    target_head = git(repo, 'rev-parse', f'{target}^{{commit}}').stdout.decode().strip()
    ancestry = git(repo, 'merge-base', '--is-ancestor', old_head, target_head, check=False)
    if ancestry.returncode not in (0, 1):
        raise MigrationError(ancestry.stderr.decode(errors='replace').strip() or 'could not check commit ancestry')
    local_commits = ancestry.returncode == 1
    original = snapshot(repo)
    dirty = bool(original[0])
    if not dirty and not local_commits:
        if not preserve_only and old_head != target_head:
            git(repo, 'merge', '--ff-only', target_head)
        verify_aligned(repo, old_head if preserve_only else target_head)
        print('tmux-agent-workbench: no local work to preserve' if preserve_only else
              'tmux-agent-workbench: main checkout is aligned with the release', flush=True)
        return

    destination, branch = create_backup(repo, root, old_head)
    print(f'tmux-agent-workbench: preserving local work in {destination} (branch {branch})', flush=True)
    new_stash = b''
    stash_marker = f'workbench migration to {branch}'
    try:
        if dirty:
            if snapshot(repo) != original:
                raise MigrationError('local changes changed before migration began')
            stash_env = os.environ.copy()
            stash_env.update(GIT_AUTHOR_NAME='Workbench migration', GIT_AUTHOR_EMAIL='workbench@localhost',
                             GIT_COMMITTER_NAME='Workbench migration', GIT_COMMITTER_EMAIL='workbench@localhost')
            git(repo, 'stash', 'push', '--include-untracked', '-m', stash_marker,
                env=stash_env)
            new_stash = find_stash(repo, stash_marker)
            if not new_stash:
                raise MigrationError('Git did not create the expected recovery stash')
            git(destination, 'stash', 'apply', '--index', new_stash.decode())
            if snapshot(destination) != original:
                raise MigrationError('recovery worktree does not match the original staged, unstaged and untracked files')
            if snapshot(repo)[0]:
                raise MigrationError('new local changes appeared while migrating')
        reject_overwrites(repo, target)
        reject_overwrites(repo, target, include_untracked=True)
        if preserve_only:
            verify_aligned(repo, old_head)
        elif local_commits:
            git(repo, 'reset', '--hard', target_head)
        elif old_head != target_head:
            git(repo, 'merge', '--ff-only', target_head)
        if not preserve_only:
            verify_aligned(repo, target_head)
    except (MigrationError, OSError) as error:
        current_stash = new_stash or find_stash(repo, stash_marker)
        if current_stash:
            print(f'tmux-agent-workbench: recovery stash retained: {current_stash.decode()}', file=sys.stderr)
            current_head = git(repo, 'rev-parse', 'HEAD', check=False)
            status = git(repo, 'status', '--porcelain=v1', '-z', '--untracked-files=all', check=False)
            if (current_head.returncode == 0 and current_head.stdout.decode().strip() == old_head
                    and status.returncode == 0 and not status.stdout):
                restored = git(repo, 'stash', 'apply', '--index', current_stash.decode(), check=False)
                if restored.returncode == 0:
                    print('tmux-agent-workbench: restored original changes to the installation checkout', file=sys.stderr)
        raise MigrationError(f'{error}; recovery worktree: {destination}') from error
    if new_stash:
        if stash_ref(repo) == new_stash:
            git(repo, 'stash', 'drop', 'stash@{0}')
        else:
            print(f'tmux-agent-workbench: recovery stash retained: {new_stash.decode()}', flush=True)
    print('tmux-agent-workbench: local work preserved; original branch unchanged' if preserve_only else
          'tmux-agent-workbench: main checkout is aligned with the release', flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--target', required=True)
    parser.add_argument('--recovery-root', type=Path, required=True)
    parser.add_argument('--preserve-only', action='store_true')
    args = parser.parse_args()
    try:
        migrate(args.repo, args.target, args.recovery_root, args.preserve_only)
    except (MigrationError, OSError) as error:
        print(f'tmux-agent-workbench: migration failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
