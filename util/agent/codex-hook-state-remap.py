"""Preserve Codex hook reviews when agent-hooks-prune removes JSON handlers."""

import json
from pathlib import Path
import re
import sys
import tomllib


def remap(config, source_path, original, cleaned):
    mapping = {}
    for event, groups in original.get('hooks', {}).items():
        label = re.sub(r'(?<!^)([A-Z])', r'_\1', event).lower()
        remaining = iter(enumerate(cleaned.get('hooks', {}).get(event, [])))
        next_group = next(remaining, None)
        for group_index, group in enumerate(groups):
            # Groups retain all metadata except their filtered handler list.
            metadata = {k: v for k, v in group.items() if k != 'hooks'}
            match = next_group is not None and metadata == {
                k: v for k, v in next_group[1].items() if k != 'hooks'
            }
            kept = next_group[1].get('hooks', []) if match else []
            # A fully removed group may have the same metadata as a later one.
            if match and not all(handler in group.get('hooks', []) for handler in kept):
                match = False
                kept = []
            handler_index = 0
            for index, handler in enumerate(group.get('hooks', [])):
                old = f'{source_path}:{label}:{group_index}:{index}'
                new = None
                if handler_index < len(kept) and handler == kept[handler_index]:
                    new = f'{source_path}:{label}:{next_group[0]}:{handler_index}'
                    handler_index += 1
                mapping[old] = new
            if match:
                if handler_index != len(kept):
                    raise ValueError('cleaned hooks are not an ordered subset')
                next_group = next(remaining, None)
        if next_group is not None:
            raise ValueError('cleaned hooks contain unexpected groups')

    parsed = tomllib.loads(config)
    state = parsed.get('hooks', {}).get('state', {})
    expected = {}
    for key, value in state.items():
        target = mapping.get(key, key)
        if target is not None:
            expected[target] = value

    output = []
    skipping = False
    for line in config.splitlines(keepends=True):
        if line.lstrip().startswith('['):
            # Only treat a line as a header when it parses independently.
            try:
                header = tomllib.loads(line)
            except tomllib.TOMLDecodeError:
                header = None
            if header is not None:
                skipping = False
                entries = header.get('hooks', {}).get('state', {})
                if len(entries) == 1:
                    key = next(iter(entries))
                    if key in mapping:
                        target = mapping[key]
                        if target is None:
                            skipping = True
                        elif target != key:
                            line = f'[hooks.state.{json.dumps(target)}]\n'
        if not skipping:
            output.append(line)
    result = ''.join(output)
    if state:
        parsed['hooks']['state'] = expected
    if tomllib.loads(result) != parsed:
        raise ValueError('unsupported TOML review-state layout; configuration left unchanged')
    return result


if __name__ == '__main__':
    old_json, new_json, config_path, output_path = map(Path, sys.argv[1:])
    try:
        text = config_path.read_text() if config_path.exists() else ''
        result = remap(text, str(old_json), json.loads(old_json.read_text()),
                       json.loads(new_json.read_text()))
        output_path.write_text(result)
    except (OSError, ValueError) as error:
        sys.exit(f'agent-hooks-prune: cannot preserve Codex hook reviews: {error}')
