#!/usr/bin/env python3
"""Keep the Workbench installation on main and preserve local work during updates."""

import argparse
import hashlib
import os
from pathlib import Path
import pickle
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


def snapshot_hash(repo):
    return hashlib.sha256(pickle.dumps(snapshot(repo), protocol=4)).hexdigest()


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


def branch_name(repo):
    result = git(repo, 'symbolic-ref', '--quiet', '--short', 'HEAD', check=False)
    return result.stdout.decode().strip() if result.returncode == 0 else None


def check_main_available(repo):
    records = git(repo, 'worktree', 'list', '--porcelain', '-z').stdout.split(b'\0\0')
    for record in records:
        fields = record.split(b'\0')
        if b'branch refs/heads/main' in fields:
            owner = next((field[9:] for field in fields if field.startswith(b'worktree ')), b'')
            if owner and Path(os.fsdecode(owner)).resolve() != repo:
                raise MigrationError(f'main is already checked out in another worktree: {os.fsdecode(owner)}')


def discard_backup(repo, destination, branch):
    result = git(repo, 'worktree', 'remove', '--force', str(destination), check=False)
    if result.returncode == 0:
        git(repo, 'branch', '-d', branch, check=False)
    else:
        print(f'tmux-agent-workbench: temporary backup retained: {destination}', file=sys.stderr)


def reapply_stash(repo, target, root, stash, original_untracked):
    root.mkdir(parents=True, exist_ok=True)
    trial = root / f'.reapply-{uuid.uuid4().hex}'
    git(repo, 'worktree', 'add', '--detach', str(trial), target)
    try:
        if snapshot(trial)[0]:
            raise MigrationError('the trial worktree is not clean before stash restoration')
        applied = git(trial, 'stash', 'apply', '--index', stash.decode(), check=False)
        if applied.returncode:
            raise MigrationError('local changes conflict with the updated main; they remain in the recovery worktree and stash')
        expected = snapshot(trial)
        for name, signature in original_untracked:
            if hash_file(trial / os.fsdecode(name)) != signature:
                raise MigrationError('an untracked file was not restored correctly in the trial worktree')
        if snapshot(repo)[0]:
            raise MigrationError('new local changes appeared before stash restoration')
        git(repo, 'stash', 'apply', '--index', stash.decode())
        if snapshot(repo) != expected:
            raise MigrationError('restored local changes do not match the verified trial worktree')
        for name, signature in original_untracked:
            if hash_file(repo / os.fsdecode(name)) != signature:
                raise MigrationError('an untracked file was not restored correctly in the installation checkout')
    finally:
        removed = git(repo, 'worktree', 'remove', '--force', str(trial), check=False)
        if removed.returncode:
            print(f'tmux-agent-workbench: trial worktree could not be removed: {trial}', file=sys.stderr)


def migrate_legacy_branch(repo, target, root, original_branch):
    check_main_available(repo)
    reject_overwrites(repo, 'refs/heads/main')
    head = git(repo, 'rev-parse', 'HEAD').stdout.decode().strip()
    destination, temporary_branch, legacy_stash, original_untracked = migrate(
        repo, target, root, preserve_only=True, force_backup=True, keep_stash=True)
    try:
        if original_branch:
            branch_head = git(repo, 'rev-parse', f'refs/heads/{original_branch}^{{commit}}').stdout.decode().strip()
            if branch_head != head:
                raise MigrationError('the development branch changed during migration')
        git(repo, 'switch', 'main')
        if original_branch:
            git(destination, 'switch', original_branch)
            if (branch_name(destination) != original_branch or
                    git(destination, 'rev-parse', 'HEAD').stdout.decode().strip() != head):
                raise MigrationError('the development branch did not attach to the preserved worktree')
            git(repo, 'branch', '-D', temporary_branch)
            print(f'tmux-agent-workbench: moved branch {original_branch} to {destination}', flush=True)
        else:
            print(f'tmux-agent-workbench: moved detached work to {destination} (branch {temporary_branch})', flush=True)
        verify_aligned(repo, git(repo, 'rev-parse', 'HEAD').stdout.decode().strip())
        migrate(repo, target, root)
        if legacy_stash:
            updated_head = git(repo, 'rev-parse', 'HEAD').stdout.decode().strip()
            reapply_stash(repo, updated_head, root, legacy_stash, original_untracked)
            if stash_ref(repo) == legacy_stash:
                git(repo, 'stash', 'drop', 'stash@{0}')
            else:
                print(f'tmux-agent-workbench: recovery stash retained: {legacy_stash.decode()}', flush=True)
            print('tmux-agent-workbench: reapplied local changes on updated main', flush=True)
    except (MigrationError, OSError) as error:
        if legacy_stash:
            print(f'tmux-agent-workbench: recovery stash retained: {legacy_stash.decode()}', file=sys.stderr)
            current_head = git(repo, 'rev-parse', 'HEAD', check=False)
            status = git(repo, 'status', '--porcelain=v1', '-z', '--untracked-files=all', check=False)
            if (branch_name(repo) == original_branch and current_head.returncode == 0
                    and current_head.stdout.decode().strip() == head
                    and status.returncode == 0 and not status.stdout):
                git(repo, 'stash', 'apply', '--index', legacy_stash.decode(), check=False)
        raise MigrationError(f'{error}; preserved development worktree: {destination}') from error


def migrate(repo, target, root, preserve_only=False, force_backup=False, keep_stash=False):
    repo = repo.resolve()
    reject_unsafe_state(repo)
    reject_overwrites(repo, target)
    initial_branch = branch_name(repo)
    if not preserve_only and initial_branch != 'main':
        return migrate_legacy_branch(repo, target, root, initial_branch)
    old_head = git(repo, 'rev-parse', 'HEAD').stdout.decode().strip()
    target_head = git(repo, 'rev-parse', f'{target}^{{commit}}').stdout.decode().strip()
    ancestry = git(repo, 'merge-base', '--is-ancestor', old_head, target_head, check=False)
    if ancestry.returncode not in (0, 1):
        raise MigrationError(ancestry.stderr.decode(errors='replace').strip() or 'could not check commit ancestry')
    local_commits = ancestry.returncode == 1
    original = snapshot(repo)
    dirty = bool(original[0])
    if not dirty and not local_commits and not force_backup:
        if not preserve_only and old_head != target_head:
            git(repo, 'merge', '--ff-only', target_head)
        verify_aligned(repo, old_head if preserve_only else target_head)
        print('tmux-agent-workbench: no local work to preserve' if preserve_only else
              'tmux-agent-workbench: main checkout is aligned with the release', flush=True)
        return None

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
            if new_stash:
                reapply_stash(repo, target_head, root, new_stash, original[3])
    except (MigrationError, OSError) as error:
        current_stash = new_stash or find_stash(repo, stash_marker)
        if current_stash:
            print(f'tmux-agent-workbench: recovery stash retained: {current_stash.decode()}', file=sys.stderr)
            current_head = git(repo, 'rev-parse', 'HEAD', check=False)
            status = git(repo, 'status', '--porcelain=v1', '-z', '--untracked-files=all', check=False)
            if (branch_name(repo) == initial_branch and current_head.returncode == 0
                    and current_head.stdout.decode().strip() == old_head
                    and status.returncode == 0 and not status.stdout):
                restored = git(repo, 'stash', 'apply', '--index', current_stash.decode(), check=False)
                if restored.returncode == 0:
                    print('tmux-agent-workbench: restored original changes to the installation checkout', file=sys.stderr)
        raise MigrationError(f'{error}; recovery worktree: {destination}') from error
    if new_stash and not keep_stash:
        if stash_ref(repo) == new_stash:
            git(repo, 'stash', 'drop', 'stash@{0}')
        else:
            print(f'tmux-agent-workbench: recovery stash retained: {new_stash.decode()}', flush=True)
    if dirty and not preserve_only:
        print('tmux-agent-workbench: reapplied local changes on updated main', flush=True)
        if not local_commits:
            discard_backup(repo, destination, branch)
    print('tmux-agent-workbench: local work preserved; original branch unchanged' if preserve_only else
          'tmux-agent-workbench: main checkout is aligned with the release', flush=True)
    return destination, branch, new_stash, original[3]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--target')
    parser.add_argument('--recovery-root', type=Path)
    parser.add_argument('--preserve-only', action='store_true')
    parser.add_argument('--fingerprint', action='store_true')
    args = parser.parse_args()
    try:
        if args.fingerprint:
            print(snapshot_hash(args.repo))
        else:
            if not args.target or not args.recovery_root:
                parser.error('--target and --recovery-root are required unless --fingerprint is set')
            migrate(args.repo, args.target, args.recovery_root, args.preserve_only)
    except (MigrationError, OSError) as error:
        print(f'tmux-agent-workbench: migration failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
