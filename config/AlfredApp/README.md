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
│       ├── user.workflow.kill-process -> ../../kill-process
│       └── user.workflow.lark-docs   -> ../../lark-docs
├── amphetamine/   convert/   dark-mode/   kill-process/   lark-docs/
│                                                       workflow sources
└── .gitignore
```

## How it is wired

Alfred stores the path of its sync folder in
`~/Library/Application Support/Alfred/prefs.json`. That indirection exists so the
bundle can live in Dropbox or iCloud; here it points into this repo instead:

```
prefs.json .current     -> ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/config/AlfredApp/Alfred.alfredpreferences
prefs.json .syncfolders -> ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/config/AlfredApp
```

`util/macos/alfred-prefs-folder` sets that (idempotently), and
`bootstrap/macos.sh` calls it from `set_macos_configs`. It is the **only** install
step — the workflow symlinks are repo-relative and tracked, so they resolve on
any machine straight out of a fresh clone. There are no per-workflow installers.

Alfred needs to have launched once for `prefs.json` to exist, so on a brand-new
Mac: install Alfred, open it, apply the Powerpack licence, then run
`alfred-prefs-folder`.

### Snippets are deny-by-default

**This repo is public.** Snippet collections are free text typed in over years,
and they are the one part of this bundle that reliably accumulates things that
must not be published — the `Work` collection held a live OpenAI API key, and
`Email` holds personal and corporate addresses.

So `.gitignore` treats `snippets/` as a **whitelist**: everything under it is
ignored, and each collection judged safe is re-included by name. A blacklist would
only defend against the collections someone already thought of; a collection
created next month would be committed before anyone looked at it.

Because the bundle is the live directory, an ignored collection still works in
Alfred exactly as before — it just stays local. Adding a collection to the
whitelist means reading it first.

The same caution applies to anything else free-form that Alfred stores here.
`preferences/features/websearch/prefs.plist` is tracked and currently contains
`code.byted.org` searches — internal, though not secret. Worth a look before
sharing this repo more widely.

### Not tracked, on purpose

Everything below is per-machine or regenerable, and lives outside the bundle in
`~/Library/Application Support/Alfred/`:

| | why |
| --- | --- |
| `powerpack.*.dat` | licence, machine-local |
| `Databases/` | clipboard history, knowledge (usage ranking), file cache |
| `Workflow Data/` | workflow runtime state |
| `preferences/local/<machine-hash>/` | per-machine appearance / clipboard retention (gitignored *inside* the bundle) |
| `snippets/<non-whitelisted>/` | see above |

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
