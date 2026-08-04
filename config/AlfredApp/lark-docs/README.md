# Lark Docs for Alfred

Browse recent Lark/Feishu docs and search all of Lark from Alfred.

## Keywords

| Keyword | What it does                                                       |
| ------- | ------------------------------------------------------------------ |
| `ld`    | Show recent docs. Type to filter recents *and* search all of Lark. |

On a result: `↩` open in browser · `⌘↩` copy link · `⌥↩` copy title + link (Markdown).

There is **no login keyword**. When the session has expired, `ld` shows a
*Sign in to Lark* row and `↩` on it opens Chrome to refresh the cookie jar — the
entry point appears exactly when it is needed instead of being a keyword you have
to remember. It fires the workflow's `login` External Trigger, also reachable as
`alfred://runtrigger/com.lukew.larkdocs/login/` or by running `node auth.mjs`.

## How it works

The Feishu docs web app (`bytedance.larkoffice.com`) exposes two cookie-authed
REST endpoints that this workflow calls directly:

- **Recent** — `GET /space/api/explorer/recent/list/`
- **Search** — `GET /space/api/bff/workspace/storage/list/?query=…`

`ld` always loads the recent list (cached 5 min) and filters it locally by an
incremental, case-insensitive, AND-of-words match. For queries of 2+ characters
it also calls the server search and merges those results below the recent hits
(deduped). Search responses are cached 1 min.

`auth.mjs` launches a dedicated-profile Chrome (`~/.config/lark-alfred/chrome`)
on a CDP port, waits until the session authenticates, then extracts the cookie
jar via the DevTools protocol and saves it to `~/.config/lark-alfred/cookies`
(mode 600). The profile persists, so later refreshes are silent (no QR).

### Files

- `search.mjs` — Alfred Script Filter backend (`node search.mjs "<query>"`).
- `auth.mjs`   — login / cookie refresh.
- `lib.mjs`    — shared API + formatting helpers (no external deps; uses global `fetch`).
- `info.plist` — the Alfred workflow.

State lives outside the repo: `~/.config/lark-alfred/` (cookies, Chrome profile)
and `~/.cache/lark-alfred/` (recent/search caches).

## Requirements

- Node ≥ 18 (Homebrew `node`; v18+ for global `fetch`).
- Google Chrome (for the sign-in flow).
- Alfred with Powerpack.

## Install

Nothing to run. Alfred's sync folder is `~/.dotfiles/config/AlfredApp`, and
`Alfred.alfredpreferences/workflows/user.workflow.lark-docs` is a repo-relative
symlink back to this directory — both are tracked, so a fresh clone is already
wired up. See `../README.md`.

Run `ld` once; if there is no session yet it offers the *Sign in to Lark* row.
