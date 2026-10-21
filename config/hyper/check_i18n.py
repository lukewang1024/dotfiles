"""Fail closed on new Hyper modules, missing translations and literal UI copy.

This is a static guard, not a Lua/AHK data-flow analyzer. Dynamic device/app names
and external diagnostics remain data. Behavioral tests exercise both languages.
"""
import ast
import io
import json
from pathlib import Path
import re
import tokenize

from localize import catalog, validate_pair

ROOT = Path(__file__).resolve().parents[2]
QUOTED = r'''(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')'''
LUA_TOKENS = re.compile(r'--\[\[.*?\]\]|--[^\n]*|' + QUOTED + r'|\[\[.*?\]\]', re.S)
PROSE = re.compile(r'[\u3400-\u9fff]|[A-Za-z]{2,}[ \t]+[A-Za-z]{2,}')
UI_SITE = re.compile(r'(?:\b(?:text|title|subText)\s*=|\b(?:alert|toast|notify|hyperNotice|setTitle|setTooltip)\s*\()\s*$')
TRANSLATE = re.compile(r'(?:\b(?:t|tr|hyperText)\s*\(\s*|\btranslate\s*\(\s*\w+\s*,\s*)$')
LUA_ENTRY = re.compile(r'(?:\[(' + QUOTED + r')\]|(\w+))\s*=\s*\{\s*en\s*=\s*(' + QUOTED + r')\s*,\s*zh\s*=\s*(' + QUOTED + r')\s*\}')


def lua_catalog(source):
    return {(quoted[1:-1] if quoted else key): [en[1:-1], zh[1:-1]]
            for quoted, key, en, zh in LUA_ENTRY.findall(source)}


def source_paths(root):
    paths = set((root / 'config/hammerspoon/private/modules').rglob('*.lua'))
    paths.update((root / 'config/hyper').rglob('*.py'))
    paths.update((root / 'config/autohotkey/lib').glob('hyper*.ahk'))
    paths.add(root / 'util/linux/hyper')
    return {path.relative_to(root).as_posix() for path in paths
            if not path.name.startswith('test_') and 'generated' not in path.name}


def strings(source, suffix):
    if suffix == '.py' or suffix == 'hyper':
        offsets = [0]
        for line in source.splitlines(keepends=True):
            offsets.append(offsets[-1] + len(line))
        for token in tokenize.generate_tokens(io.StringIO(source).readline):
            if token.type == tokenize.STRING and not token.string.startswith(('"""', "'''")):
                try:
                    value = ast.literal_eval(token.string)
                except (ValueError, SyntaxError):
                    continue
                if isinstance(value, str):
                    yield offsets[token.start[0]-1] + token.start[1], value
    elif suffix == '.ahk':
        for match in re.finditer(r';[^\n]*|"(?:""|[^"\n])*"', source):
            if match[0].startswith('"'):
                yield match.start(), match[0][1:-1].replace('""', '"')
    else:
        for match in LUA_TOKENS.finditer(source):
            if match[0].startswith('--'):
                continue
            if match[0].startswith('[['):
                yield match.start(), match[0][2:-2]
            else:
                yield match.start(), re.sub(r'''\\(['"\\])''', r'\1', match[0][1:-1])


def source_errors(path, source, policy, labels):
    errors = []
    if policy['kind'] == 'legacy':
        return errors
    if policy['kind'] == 'internal':
        # These classifications must not conceal a newly added UI surface.
        code = LUA_TOKENS.sub('', source) if path.endswith('.lua') else source
        if path.endswith(('.lua', '.ahk')) and re.search(r'hs\.(?:alert|dialog|menubar|canvas)|\b(?:hyperNotice|MsgBox|TrayTip)\b', code):
            errors.append(f'{path}: UI API in a non-UI module; classify and audit it as ui')
        return errors
    if policy['kind'] == 'catalog':
        pairs = lua_catalog(source)
        if any(len(pairs) != len(re.findall(r'\b' + lang + r'\s*=', source)) for lang in ('en', 'zh')) or not pairs:
            errors.append(f'{path}: every local catalog entry must have en and zh')
        for key, pair in pairs.items():
            try:
                validate_pair(f'{path}:{key}', pair)
            except ValueError as error:
                errors.append(str(error))
        return errors
    allowed = policy.get('literals', {})
    if path.endswith('.ahk'):
        # AHK v1 also permits unquoted text in legacy command syntax.
        for match in re.finditer(r'(?mi)^\s*(MsgBox|TrayTip|ToolTip)\s*,([^\n]*)', source):
            parts = match[2].strip().split(',')
            index = 2 if match[1].lower() == 'msgbox' and len(parts) >= 3 else (1 if match[1].lower() == 'traytip' else 0)
            text = parts[index].strip()
            if text and not text.startswith('%'):
                errors.append(f'{path}: literal {match[1]} text; use a translated expression')
    for literal, reason in allowed.items():
        if not reason.strip():
            errors.append(f'{path}: explain why {literal!r} is not translatable UI')
    for offset, value in strings(source, Path(path).suffix or 'hyper'):
        prefix = source[max(0, offset-100):offset]
        location = f'{path}:{source.count(chr(10), 0, offset)+1}'
        if TRANSLATE.search(prefix) and value and not value.endswith('.'):
            if value not in labels['en'] or value not in labels['zh']:
                errors.append(f'{location}: unknown translation key {value!r}')
        if value in labels['en'] or value in allowed:
            continue
        if PROSE.search(value) or (UI_SITE.search(prefix) and re.search(r'[A-Za-z]', value)):
            errors.append(f'{location}: literal UI text {value!r}; use the bilingual catalog')
    return errors


def validate_repository(root=ROOT):
    config = root / 'config/hyper'
    labels = catalog(json.loads((config / 'keys.json').read_text(encoding='utf-8')), config / 'locales.json')
    policies = json.loads((config / 'i18n-sources.json').read_text(encoding='utf-8'))
    paths = source_paths(root)
    # A retired module must never silently re-enter the live dependency graph.
    pending = [root / 'config/hammerspoon/private/workbench.lua']
    live = set()
    while pending:
        path = pending.pop()
        if path in live or not path.is_file():
            continue
        live.add(path)
        for dependency in re.findall(r'''require\s*\(?\s*['"](private/[^'"]+)['"]''', path.read_text()):
            pending.append(root / 'config/hammerspoon' / (dependency + '.lua'))
    errors = [f'{path}: new module needs an i18n policy and bilingual tests'
              for path in sorted(paths - policies.keys())]
    errors += [f'{path}: stale i18n source policy' for path in sorted(policies.keys() - paths)]
    for path in sorted(paths & policies.keys()):
        policy = policies[path]
        if policy.get('kind') == 'legacy' and root / path in live:
            errors.append(f'{path}: legacy module is loaded; classify and audit it as ui/internal')
        if policy.get('kind') not in ('ui', 'internal', 'catalog', 'legacy') or not policy.get('reason'):
            errors.append(f'{path}: explain the module classification')
            continue
        module_labels = {lang: dict(values) for lang, values in labels.items()}
        if policy.get('catalog'):
            catalog_path = policy['catalog']
            if policies.get(catalog_path, {}).get('kind') != 'catalog':
                errors.append(f'{path}: referenced catalog must itself be validated')
            else:
                for key, pair in lua_catalog((root / catalog_path).read_text()).items():
                    for index, lang in enumerate(('en', 'zh')):
                        module_labels[lang][key] = pair[index]
        errors.extend(source_errors(path, (root / path).read_text(encoding='utf-8-sig'), policy, module_labels))
    if errors:
        raise ValueError('\n'.join(errors))


if __name__ == '__main__':
    validate_repository()
    print('Hyper i18n: catalogs, source coverage and UI literals passed')
