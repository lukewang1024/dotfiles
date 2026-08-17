# Convert — Alfred workflow

Free-form unit and currency conversion. Replaces
[alfred-convert](https://github.com/deanishe/alfred-convert) 3.7 by Dean Jackson,
which needed Python 2, [`pint`](https://pint.readthedocs.io) and
`Alfred-Workflow` — none of which survive on a modern macOS (`/usr/bin/python`
was removed in macOS 12.3, and the vendored libraries were never in the copy that
was installed here anyway).

Standard library only, `/usr/bin/python3`.

## Commands

| Query | Result |
| --- | --- |
| `conv 100 usd cny` | `= 676.5857 CNY` |
| `conv 100 usd` | every favourite currency at once |
| `conv 1200*3 hkd sgd` | the amount may be arithmetic |
| `conv $100 to jpy` | currency symbols — `$ ¥ € £ ₩ ₹ HK$ S$ NT$ A$ C$` |
| `conv 100 rmb usd` | spoken names — `rmb`, `yuan`, `yen`, `euro`, `quid`, … |
| `conv 10 km mi` | units |
| `conv 10 kg` | the dimension's usual companions |
| `conv 72 f c` | temperature |
| `conv 1 gb mib` | decimal and binary byte ladders in one table |

↩ copies the bare number (the common case is pasting it somewhere); ⌘↩ copies it
with the unit attached. ⌘L shows it in Large Type.

Dimensions: length, mass, volume, area, speed, time, data, temperature,
pressure, energy, power, angle, frequency.

## Configuration

Two workflow variables, editable in Alfred's *Configure Workflow* sheet or
directly in `info.plist`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `CONVERT_CURRENCIES` | `CNY,USD,HKD,SGD,EUR,JPY,GBP` | Targets for a bare `conv 100 usd` |
| `CONVERT_DECIMALS` | `4` | Significant decimals between 1 and 1000 |

Alfred stores the edited values in `prefs.plist` next to this README — which,
because the workflow is a symlink into the repo, means changing them in the UI
shows up as a normal diff.

## Exchange rates

`rates.py` caches USD-based rates in `$XDG_CACHE_HOME/alfred-convert/rates.json`
and serves them **stale-while-revalidate**: a Script Filter runs on every
keystroke, so it must never wait on the network. A stale cache is used
immediately and a detached refresh is spawned; only a completely cold cache
blocks, and then once. Every currency row carries the provider and the age of the
number in its subtitle, and past 14 days the workflow refuses to quote rather
than convert money at a rate it can't stand behind.

Providers, in order:

1. `open.er-api.com` — ~166 currencies, no key, daily
2. `api.frankfurter.dev` — ECB reference rates, ~30 currencies, no key, weekdays

Refresh by hand with `/usr/bin/python3 rates.py`.

**Fiat only.** Crypto was deliberately left out: every keyless quote source tried
(CoinGecko, Coinbase) is unreachable from this machine's network, and a
conversion that silently works at home and fails at the office is worse than one
that was never offered.

## Install

Nothing to run. Alfred's sync folder is `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/config/AlfredApp`, and
`Alfred.alfredpreferences/workflows/user.workflow.convert` is a repo-relative
symlink back to this directory — both are tracked, so a fresh clone is already
wired up. See `../README.md`.

Alfred caches `info.plist` in memory, so **restart Alfred** after changing it:

```sh
osascript -e 'tell application "Alfred 5" to quit'; open -a "Alfred 5"
```

The Python files are read live on each run and need no restart.

## Notes for future edits

Two collisions cost real thought, and both are load-bearing:

- **`in` is both a preposition and an inch.** `conv 10 in cm` and `conv 10 cm in`
  must both work. `split_units()` only treats a connector token as a connector
  when something precedes it (index ≥ 1), and falls back to reading it as a unit
  when dropping it would leave no target.
- **Unit and currency namespaces overlap.** `cup` is a volume *and* the Cuban
  peso (`CUP`). `candidates()` therefore returns every reading of a token and
  `pair()` picks the combination that is actually convertible — so `conv 5 cup ml`
  is volume and `conv 100 cup usd` is money, with no special-casing.

Also worth knowing:

- The amount is parsed by consuming operator-joined numbers one at a time rather
  than regexing for "an expression". That is what stops `10 euro` being read as
  `10 e` (scientific notation).
- Arithmetic goes through `ast`, not `eval` — constants and `+ - * / **` only, no
  names and no calls.
- Temperature is affine, not a multiplier, so those units carry a `to_base` /
  `from_base` pair instead of a factor (`units.TEMPERATURE`).
- `alfredfiltersresults` is **false**: `convert.py` produces the answer for the
  query, so letting Alfred re-filter the rows would hide the CNY result the
  moment you typed `cny`.
- `scriptargtype` is **1** (input as argv → `"$1"`). `0` means `{query}`
  substitution instead, and getting it backwards passes the literal string
  `{query}` to the script — `main()` guards against that rather than trying to
  convert it.
- `¥` maps to CNY, not JPY. It is genuinely ambiguous; CNY is the one being typed
  day to day, and `conv 100 jpy …` is the unambiguous spelling.
- Data units are matched case-insensitively (`gb` and `GB` are both gigabytes) —
  Alfred queries are typed lowercase in practice, so honouring the SI bit/byte
  case distinction would break more queries than it would fix. Use `bit` when you
  mean bits.
- Pinned to `/usr/bin/python3` (system 3.9) for the same reason as
  `../amphetamine`: `python3` on `PATH` is a pyenv shim Alfred's environment does
  not reliably resolve. No 3.10+ syntax.
