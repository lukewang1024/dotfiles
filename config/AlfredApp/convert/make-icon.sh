#!/usr/bin/env bash
# Regenerate icon.png — two opposed arrows, the usual "convert" glyph.
# Authored as SVG and rendered with rsvg-convert, same as ../lark-docs.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

command -v rsvg-convert >/dev/null || { echo "need rsvg-convert (brew install librsvg)" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/icon.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="0 0 160 160">
  <rect x="8" y="8" width="144" height="144" rx="34" fill="#3B7DD8"/>
  <g fill="none" stroke="#FFFFFF" stroke-width="10" stroke-linecap="round" stroke-linejoin="round">
    <path d="M46 62 H112"/>
    <path d="M94 44 L112 62 L94 80"/>
    <path d="M114 98 H48"/>
    <path d="M66 80 L48 98 L66 116"/>
  </g>
</svg>
SVG

rsvg-convert -w 256 -h 256 "$tmp/icon.svg" -o icon.png
echo "wrote icon.png"
