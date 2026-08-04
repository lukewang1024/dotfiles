# Alfred

Alfred's entire configuration lives here, in git. `Alfred.alfredpreferences/` is
not a copy or a backup — it is the live bundle Alfred reads and writes.

```
config/AlfredApp/
├── Alfred.alfredpreferences/          Alfred's sync folder (it reads/writes this)
│   ├── preferences/                     settings: hotkeys, web searches, appearance
│   │   └── local/<machine-hash>/           gitignored — per-machine
│   ├── snippets/                        snippet collections
│   ├── resources/                       custom web-search icons
│   └── workflows/
│       ├── user.workflow.amphetamine -> ../../amphetamine
│       ├── user.workflow.convert     -> ../../convert
│       ├── user.workflow.dark-mode   -> ../../dark-mode
│       └── user.workflow.lark-docs   -> ../../lark-docs
├── amphetamine/   convert/   dark-mode/   lark-docs/     workflow sources
└── .gitignore
```

## How it is wired

Alfred stores the path of its sync folder in
`~/Library/Application Support/Alfred/prefs.json`. That indirection exists so the
bundle can live in Dropbox or iCloud; here it points into this repo instead:

```
prefs.json .current     -> ~/.dotfiles/config/AlfredApp/Alfred.alfredpreferences
prefs.json .syncfolders -> ~/.dotfiles/config/AlfredApp
```

`util/macos/alfred-prefs-folder` sets that (idempotently), and
`bootstrap/macos.sh` calls it from `set_macos_configs`. It is the **only** install
step — the workflow symlinks are repo-relative and tracked, so they resolve on
any machine straight out of a fresh clone. There are no per-workflow installers.

Alfred needs to have launched once for `prefs.json` to exist, so on a brand-new
Mac: install Alfred, open it, apply the Powerpack licence, then run
`alfred-prefs-folder`.

### Not tracked, on purpose

Everything below is per-machine or regenerable, and lives outside the bundle in
`~/Library/Application Support/Alfred/`:

| | why |
| --- | --- |
| `powerpack.*.dat` | licence, machine-local |
| `Databases/` | clipboard history, knowledge (usage ranking), file cache |
| `Workflow Data/` | workflow runtime state |
| `preferences/local/<machine-hash>/` | per-machine appearance / clipboard retention (gitignored *inside* the bundle) |

Alfred does not write to the bundle on launch, so the working tree stays clean —
a diff here means a setting genuinely changed.

## Editing a workflow

Alfred caches `info.plist` in memory. After changing one:

```sh
osascript -e 'tell application "Alfred 5" to quit'; open -a "Alfred 5"
```

Scripts (`*.py`, `*.sh`) are read live on each run and need no restart.

Editing a workflow in Alfred's own UI writes straight into this repo through the
symlink — which is the point: those edits show up as ordinary diffs instead of
being lost.

## History

Until 2026-08 this bundle was synced between machines by Resilio Sync, and had
accumulated 99 workflow directories totalling 150 MB. Of those:

- **39** had no `info.plist` at all — leftover data directories (`packal/`,
  `vendor/`, `node_modules/`, `appicons/`) from Alfred 2/3-era installs that
  Alfred had long since stopped loading. 49 MB of pure residue.
- **23** could not run: `/usr/bin/php` was removed in macOS 12 and
  `/usr/bin/python` (Python 2) with it, which killed every PHP workflow
  (知乎, devdocs, V2EX, Can I Use, Workflow Searcher, GitHub, MDN Search, …) and
  every Python 2 one (StackOverflow, IME, Urban Dictionary, BetterSnip, …).
- **3** drove applications that are no longer installed (SourceTree, Fantastical,
  f.lux) — Fantastical alone squatting 20 keywords.
- The rest were work tooling superseded by `axon-cli` / `bytedcli`, or simply
  unused: Alfred's own usage database showed exactly two workflow keywords in
  active use.

What survived is here. `Convert` and `Dark Mode` were rewritten rather than kept
(see their READMEs); `Amphetamine` had already been rewritten for Amphetamine 5.x.
The retired originals were moved to `~/.local/state/alfred-retired-workflows/`
rather than deleted.
