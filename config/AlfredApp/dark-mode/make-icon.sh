#!/usr/bin/env bash
# Regenerate icon.png — a half-filled circle, the usual "appearance" glyph.
# Authored as SVG and rendered with rsvg-convert, same as ../lark-docs.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

command -v rsvg-convert >/dev/null || { echo "need rsvg-convert (brew install librsvg)" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/icon.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="0 0 160 160">
  <rect x="8" y="8" width="144" height="144" rx="34" fill="#2E3440"/>
  <circle cx="80" cy="80" r="40" fill="none" stroke="#ECEFF4" stroke-width="9"/>
  <path d="M80 40 A40 40 0 0 1 80 120 Z" fill="#ECEFF4"/>
</svg>
SVG

rsvg-convert -w 256 -h 256 "$tmp/icon.svg" -o icon.png
echo "wrote icon.png"
