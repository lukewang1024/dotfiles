#!/usr/bin/env python3
"""Machine-local shipping policy and platform-neutral dispatch (Python 3)."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit


def run(*args, capture=True):
    result = subprocess.run(args, text=True, capture_output=capture, check=True)
    return result.stdout.strip() if capture else ''


def identity(url):
    if '://' not in url and re.match(r'^(?:[^/@:]+@)?[^/:]+:', url):
        url = 'ssh://' + url.replace(':', '/', 1)
    parsed = urlsplit(url)
    if parsed.scheme in ('ssh', 'https', 'http', 'git'):
        host = (parsed.hostname or '').lower()
        port = parsed.port
        if port and (parsed.scheme, port) not in [('ssh', 22), ('https', 443), ('http', 80), ('git', 9418)]:
            host += ':' + str(port)
        path = parsed.path.strip('/')
        if path.endswith('.git'):
            path = path[:-4]
        if not host or not path:
            raise ValueError('origin must identify a repository')
        return host + '/' + path, host
    if parsed.scheme and parsed.scheme != 'file':
        raise ValueError('unsupported origin URL scheme')
    return 'file://' + str(Path(parsed.path if parsed.scheme else url).resolve()), ''


def config_path():
    return Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'code-ship/config.yml'


def read_config(path):
    if not path.exists():
        return {'version': 1, 'repositories': {}}
    data = json.loads(path.read_text())
    if not isinstance(data, dict) or data.get('version') != 1 or not isinstance(data.get('repositories'), dict):
        raise ValueError('unsupported code-ship config format')
    for policy in data['repositories'].values():
        if not isinstance(policy, dict) or any(not isinstance(value, str) for value in policy.values()):
            raise ValueError('invalid saved policy')
    return data


def save_policy(key, policy):
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with open(path.with_suffix('.lock'), 'a') as lock:
        os.chmod(lock.name, 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = read_config(path)
        data['repositories'][key] = policy
        fd, name = tempfile.mkstemp(dir=path.parent)
        try:
            with os.fdopen(fd, 'w') as out:
                json.dump(data, out, indent=2, ensure_ascii=False)
                out.write('\n')
            os.replace(name, path)
        finally:
            if os.path.exists(name):
                os.unlink(name)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo-dir', default='.')
    p.add_argument('--strategy', choices=['direct-push', 'manual-merge', 'auto-merge'])
    p.add_argument('--target-branch', help='target name, or auto to follow origin HEAD')
    p.add_argument('--provider', help='github or an installed provider name')
    p.add_argument('--remember', action='store_true', help='persist explicit overrides before shipping')
    p.add_argument('--configure', action='store_true', help='save policy only; never ship')
    p.add_argument('--show-policy', action='store_true', help='inspect policy without network or writes')
    p.add_argument('--dry-run', action='store_true')
    p.add_argument('--title')
    p.add_argument('--description', default='')
    p.add_argument('--description-file')
    p.add_argument('--draft', action='store_true')
    p.add_argument('--no-remove-source-branch', action='store_true')
    p.add_argument('--poll-interval', type=int, default=15)
    p.add_argument('--poll-timeout', type=int, default=1800)
    p.add_argument('--skip-reconcile', action='store_true', help='compatibility flag; local branches are preserved')
    a = p.parse_args()
    os.chdir(a.repo_dir)
    run('git', 'rev-parse', '--show-toplevel')
    urls = run('git', 'remote', 'get-url', '--push', '--all', 'origin').splitlines()
    if len(urls) != 1:
        raise ValueError('origin must have exactly one push URL')
    key, host = identity(urls[0])
    if identity(run('git', 'remote', 'get-url', 'origin'))[0] != key:
        raise ValueError('origin fetch and push repositories differ; configure matching URLs')
    policy = dict(read_config(config_path())['repositories'].get(key, {}))
    for field, value in [('strategy', a.strategy), ('target-branch', a.target_branch), ('provider', a.provider)]:
        if value is not None:
            policy[field] = value
    if host == 'github.com':
        policy.setdefault('provider', 'github')
    if a.show_policy:
        print(json.dumps({'repository': key, 'policy': policy, 'needsChoice': not policy.get('strategy')}))
        return 0
    if not policy.get('strategy'):
        if not sys.stdin.isatty():
            print(json.dumps({'status': 'needs-policy', 'repository': key,
                              'choices': ['direct-push', 'manual-merge', 'auto-merge']}))
            return 20
        print('首次使用，请选择并记住此仓库的策略：\n1) 直接推送\n2) 创建 PR/MR\n3) 检查通过后自动合并', file=sys.stderr)
        answer = input('选择 [1/2/3]（无默认值）: ').strip()
        if answer not in ('1', '2', '3'):
            raise ValueError('no strategy selected')
        policy['strategy'] = ['direct-push', 'manual-merge', 'auto-merge'][int(answer)-1]
        a.remember = True
    strategy = policy['strategy']
    if strategy not in ('direct-push', 'manual-merge', 'auto-merge'):
        raise ValueError('invalid saved strategy')
    target = policy.get('target-branch', 'auto')
    if target != 'auto':
        run('git', 'check-ref-format', 'refs/heads/' + target)
    provider = policy.get('provider', '')
    if provider and not re.fullmatch('[a-z][a-z0-9-]*', provider):
        raise ValueError('invalid provider name')
    if a.poll_interval <= 0 or a.poll_timeout <= 0:
        raise ValueError('poll durations must be positive')
    if a.draft and strategy != 'manual-merge':
        raise ValueError('--draft requires manual-merge')
    dry = a.dry_run or os.environ.get('CODE_SHIP_DRY_RUN') == '1'
    if dry and (a.remember or a.configure):
        raise ValueError('dry run cannot save policy')
    if a.remember or a.configure:
        save_policy(key, policy)
    if a.configure:
        print(json.dumps({'repository': key, 'policy': policy, 'saved': True}))
        return 0
    adapter = None
    if strategy != 'direct-push':
        if provider == 'github':
            if host != 'github.com':
                raise ValueError('built-in github provider requires github.com')
            if strategy == 'auto-merge':
                raise ValueError('GitHub auto-merge is not supported in this version')
            if not shutil.which('gh'):
                raise ValueError('GitHub PR creation requires gh and gh auth login')
            run('gh', 'auth', 'status', '--hostname', 'github.com')
        else:
            if not provider:
                raise ValueError('set --provider NAME for this host; no platform is inferred')
            adapter = shutil.which('code-ship-provider-' + provider)
            if not adapter:
                raise ValueError('missing code-ship-provider-' + provider + '; install the private provider package on this machine')
            run(adapter, '--check')
    branch = run('git', 'branch', '--show-current')
    if not branch:
        raise ValueError('detached HEAD not allowed')
    if run('git', 'status', '--porcelain'):
        raise ValueError('working tree not clean; commit/stash first')
    if target == 'auto':
        remote_head = run('git', 'ls-remote', '--symref', 'origin', 'HEAD')
        match = re.search(r'^ref: refs/heads/(.+)\tHEAD$', remote_head, re.M)
        if match:
            target = match[1]
        else:
            heads = run('git', 'ls-remote', '--heads', 'origin', 'main', 'master')
            target = next((b for b in ('main', 'master') if '\trefs/heads/' + b in heads), None)
            if not target:
                raise ValueError('cannot detect target; specify --target-branch')
    run('git', 'fetch', 'origin', '+refs/heads/' + target + ':refs/remotes/origin/' + target)
    base = 'refs/remotes/origin/' + target
    ahead = int(run('git', 'rev-list', '--count', base + '..HEAD'))
    if not ahead:
        raise ValueError('no commits to ship')
    if strategy == 'direct-push':
        if subprocess.run(['git', 'merge-base', '--is-ancestor', base, 'HEAD'], capture_output=True).returncode:
            raise ValueError('direct-push requires a fast-forward; integrate the remote target before retrying')
    description = Path(a.description_file).read_text() if a.description_file else a.description
    title = a.title or run('git', 'log', '-1', '--pretty=%s')
    if dry:
        print(json.dumps({'dryRun': True, 'repository': key, 'strategy': strategy, 'targetBranch': target, 'commitsAhead': ahead}))
        return 0
    if strategy == 'direct-push':
        run('git', '-c', 'push.followTags=false', 'push', 'origin', 'HEAD:refs/heads/' + target, capture=False)
        print(json.dumps({'strategy': strategy, 'targetBranch': target, 'commitsAhead': ahead}))
        return 0
    if branch == target:
        branch = 'ship/' + run('git', 'rev-parse', '--short=12', 'HEAD')
        run('git', 'checkout', '-b', branch)
    if adapter:
        env = dict(os.environ, STRATEGY=strategy, TARGET_BRANCH=target, CURRENT_BRANCH=branch,
                   FEATURE_BRANCH=branch, BASE_REF=base, HOST=host, REPO_NAME=key[len(host)+1:],
                   TITLE=title, DESCRIPTION=description, DRAFT=str(a.draft).lower(),
                   REMOVE_SOURCE=str(not a.no_remove_source_branch).lower(),
                   POLL_INTERVAL=str(a.poll_interval), POLL_TIMEOUT=str(a.poll_timeout),
                   COMMITS_AHEAD=str(ahead), SHIP_BRANCH_CREATED='false', SKIP_RECONCILE='true')
        subprocess.run([adapter], env=env, check=True)
    else:
        run('git', '-c', 'push.followTags=false', 'push', 'origin', 'HEAD:refs/heads/' + branch, capture=False)
        args = ['gh', 'pr', 'create', '--repo', key, '--head', branch, '--base', target, '--title', title, '--body', description]
        if a.draft:
            args.append('--draft')
        url = run(*args)
        print(json.dumps({'strategy': strategy, 'mrUrl': url, 'merged': False}))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, EOFError, subprocess.CalledProcessError) as error:
        print('code-ship: ' + str(error), file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr, file=sys.stderr)
        sys.exit(1)
