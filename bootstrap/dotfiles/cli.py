"""Shared CLI for all launchers; importing this module has no side effects."""
import argparse
from contextlib import redirect_stdout, redirect_stderr
import json
from pathlib import Path
import shlex
import sys

from .engine import Context, Failure, Reporter, detect_platform
from .tasks import TASKS
from . import platforms, maintenance  # register platform/maintenance tasks

PLATFORMS = ('macos', 'debian', 'arch', 'chromeos', 'termux', 'cygwin', 'windows')


def select_tasks(platform, mode, arguments):
    if mode == 'run':
        if len(arguments) < 2:
            raise Failure('Usage: init run <module> <task> [arguments]')
        module, expression, *extra = arguments
        if module not in ('env', 'shell', 'pkg', 'nix', 'linux', 'macos', 'macos-defaults', 'debian', 'arch', 'chromeos',
                          'termux', 'cygwin', 'windows', 'workbench', 'maintenance'):
            raise Failure('Unknown task module: ' + module)
        tokens = shlex.split(expression)
        if not tokens or tokens[0] not in TASKS:
            raise Failure('Unknown task; use --list-tasks. Arbitrary shell eval is no longer supported.')
        if module in PLATFORMS and module != platform and not (module == 'macos' and platform == 'macos'):
            raise Failure(f'{module} task requires the {module} platform')
        if module == 'macos-defaults' and platform != 'macos':
            raise Failure('macOS defaults require macOS')
        return [(tokens[0], tokens[1:] + extra)]
    if arguments:
        raise Failure(f'{mode} does not accept positional arguments')
    if mode in ('basic', 'sync'):
        return [('sync_setup', [])] if mode == 'sync' or platform == 'windows' else [('termux_basic_setup' if platform == 'termux' else 'basic_env_setup', [])]
    names = {'npmg': 'install_npm_packages', 'zinit': 'zinit_setup', 'kerberos': 'kerberos',
             'migrate-xdg': 'migrate_xdg', 'workbench': 'setup_distributed_workbench'}
    if mode in names:
        if platform == 'windows' and mode in ('kerberos', 'zinit'):
            raise Failure(f'{mode} is a Unix-only task')
        return [(names[mode], [])]
    if platform == 'termux':
        if mode not in ('core', 'all'):
            raise Failure('Termux supports core and all; no separate cli/gui/game set')
        return [('prepare_termux_env', [mode])]
    if platform == 'chromeos':
        if mode not in ('core', 'all'):
            raise Failure('ChromeOS supports core and all')
        return [('prepare_chromeos', [])]
    if platform == 'cygwin':
        if mode not in ('core', 'all'):
            raise Failure('Cygwin supports core and all')
        return [(n, []) for n in ('check_admin', 'setup_cygwin_env', 'install_sage', 'install_cygwin_packages')]
    if mode == 'game':
        if platform not in ('windows', 'macos', 'arch'):
            raise Failure('No gaming package set for ' + platform)
        name = 'prepare_windows_gaming' if platform == 'windows' else f'setup_{platform}_gaming'
        return [(name, [])]
    tiers = {'core': ('cli_core', 'gui_core'), 'all': ('cli_core', 'cli_extra', 'gui_core', 'gui_extra'),
             'cli': ('cli_core', 'cli_extra'), 'gui': ('gui_core', 'gui_extra')}[mode]
    plan = [('config_pacman', [])] if platform == 'arch' else []
    plan += [(f'prepare_{platform}_env_{tier}', []) for tier in tiers]
    if platform != 'windows':
        plan.append(('brew_cleanup', []))
    return plan


def main(argv=None):
    parser = argparse.ArgumentParser(description='Cross-platform dotfiles setup. Detailed output is written to XDG state logs.')
    parser.add_argument('mode', nargs='?', choices=['basic', 'core', 'all', 'cli', 'gui', 'game', 'sync', 'npmg', 'zinit', 'kerberos', 'migrate-xdg', 'workbench', 'run'])
    parser.add_argument('arguments', nargs='*')
    parser.add_argument('--dry-run', action='store_true', help='Describe actions without changing files or executing commands')
    parser.add_argument('--json', action='store_true', help='Print a machine-readable dry-run plan')
    parser.add_argument('--platform', choices=PLATFORMS, help='Override platform for dry-run inspection only')
    parser.add_argument('--list-tasks', action='store_true')
    args = parser.parse_args(argv)
    if args.list_tasks:
        print('\n'.join(sorted(TASKS)))
        return 0
    if not args.mode:
        parser.error('a mode is required')
    if args.json and not args.dry_run:
        parser.error('--json requires --dry-run')
    if args.platform and not args.dry_run:
        parser.error('--platform is only allowed with --dry-run')
    try:
        platform = args.platform or detect_platform()
        plan = select_tasks(platform, args.mode, args.arguments)
        context = Context(Path(__file__).resolve().parents[2], platform, dry_run=args.dry_run)
        context.tasks = TASKS
        if args.dry_run:
            for name, values in plan:
                context.task(name, *values)
            if args.json:
                print(json.dumps({'platform': platform, 'mode': args.mode, 'actions': context.events}, ensure_ascii=False, indent=2))
            else:
                for event in context.events:
                    print(json.dumps(event, ensure_ascii=False))
            return 0
        reporter = Reporter(context.state, platform + ' / ' + args.mode)
        context.reporter = reporter
        status = 0
        try:
            with redirect_stdout(reporter.log), redirect_stderr(reporter.log):
                for name, values in plan:
                    try:
                        context.task(name, *values)
                    except (Failure, OSError, ValueError) as exc:
                        # Fail the current category before moving to another;
                        # no trailing success echo can mask a failed command.
                        status = 1
                        # Later categories often depend on earlier runtimes.
                        break
        except KeyboardInterrupt:
            status = 130
        finally:
            reporter.close()
        return status
    except (Failure, OSError, ValueError) as exc:
        print('dotfiles: ' + str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
