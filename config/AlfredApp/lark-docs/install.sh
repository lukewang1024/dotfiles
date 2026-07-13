#!/usr/bin/env bash
# Symlink this workflow into Alfred's workflows directory so it stays in sync
# with the dotfiles repo. Safe to re-run.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Honor Alfred's configured sync folder (Preferences may live in Dropbox /
# Resilio / iCloud rather than the default location).
if [ -n "${ALFRED_PREFS:-}" ]; then
  prefs="$ALFRED_PREFS"
else
  sync="$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder 2>/dev/null || true)"
  sync="${sync/#\~/$HOME}"
  if [ -n "$sync" ] && [ -d "$sync/Alfred.alfredpreferences/workflows" ]; then
    prefs="$sync/Alfred.alfredpreferences"
  else
    prefs="$HOME/Library/Application Support/Alfred/Alfred.alfredpreferences"
  fi
fi
dest="$prefs/workflows/user.workflow.lark-docs"

if [ ! -d "$prefs/workflows" ]; then
  echo "Alfred workflows directory not found: $prefs/workflows" >&2
  echo "Open Alfred at least once (with Powerpack) first." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "warning: 'node' not on PATH — install Node (brew install node) before using the workflow." >&2
fi

ln -sfn "$src" "$dest"
echo "Linked: $dest -> $src"
echo "Reload Alfred (or toggle the workflow), then run 'll' once to sign in."
