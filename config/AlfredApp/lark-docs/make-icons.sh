#!/usr/bin/env bash
# Regenerate the workflow's icon set into ./icons/.
#   - Lark-style type badges (doc/sheet/slide/base/mindnote/wiki/file/login)
#     are authored as SVG here and rendered to PNG with rsvg-convert.
#   - Per-extension file icons are pulled from the macOS icon services via swift
#     (NSWorkspace), so they look native (pdf, pptx, zip, …).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
out="icons"
mkdir -p "$out"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

command -v rsvg-convert >/dev/null || { echo "need rsvg-convert (brew install librsvg)" >&2; exit 1; }

# A rounded-square badge with a white glyph. $1=name $2=bg color $3=inner svg
badge() {
  local name="$1" bg="$2" glyph="$3"
  cat > "$tmp/$name.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="0 0 160 160">
  <rect x="8" y="8" width="144" height="144" rx="34" fill="$bg"/>
  <g fill="none" stroke="#ffffff" stroke-width="9" stroke-linecap="round" stroke-linejoin="round">
    $glyph
  </g>
</svg>
SVG
  rsvg-convert -w 256 -h 256 "$tmp/$name.svg" -o "$out/$name.png"
}

# doc — blue page with text lines
badge doc "#3370FF" '
  <rect x="48" y="40" width="64" height="80" rx="8" fill="#ffffff" stroke="none"/>
  <line x1="62" y1="62" x2="98" y2="62" stroke="#3370FF" stroke-width="7"/>
  <line x1="62" y1="80" x2="98" y2="80" stroke="#3370FF" stroke-width="7"/>
  <line x1="62" y1="98" x2="86" y2="98" stroke="#3370FF" stroke-width="7"/>'

# sheet — green grid
badge sheet "#34C724" '
  <rect x="44" y="44" width="72" height="72" rx="8" fill="#ffffff" stroke="none"/>
  <line x1="44" y1="68" x2="116" y2="68" stroke="#34C724" stroke-width="7"/>
  <line x1="44" y1="92" x2="116" y2="92" stroke="#34C724" stroke-width="7"/>
  <line x1="80" y1="44" x2="80" y2="116" stroke="#34C724" stroke-width="7"/>'

# slide — orange presentation screen with a play triangle
badge slide "#FF8800" '
  <rect x="42" y="46" width="76" height="56" rx="8" fill="#ffffff" stroke="none"/>
  <polygon points="72,62 72,86 94,74" fill="#FF8800" stroke="none"/>
  <line x1="80" y1="102" x2="80" y2="116" stroke="#ffffff" stroke-width="8"/>'

# base — purple table with a highlighted header row
badge base "#7C3AED" '
  <rect x="44" y="44" width="72" height="72" rx="8" fill="#ffffff" stroke="none"/>
  <rect x="44" y="44" width="72" height="20" rx="8" fill="#C9B0FB" stroke="none"/>
  <line x1="44" y1="86" x2="116" y2="86" stroke="#7C3AED" stroke-width="7"/>
  <line x1="80" y1="64" x2="80" y2="116" stroke="#7C3AED" stroke-width="7"/>'

# mindnote — teal central node with two branches
badge mindnote "#0FBF9F" '
  <line x1="74" y1="80" x2="98" y2="58"/>
  <line x1="74" y1="80" x2="98" y2="102"/>
  <circle cx="62" cy="80" r="12" fill="#ffffff" stroke="none"/>
  <circle cx="104" cy="56" r="9" fill="#ffffff" stroke="none"/>
  <circle cx="104" cy="104" r="9" fill="#ffffff" stroke="none"/>'

# wiki — teal-green open book
badge wiki "#14B8A6" '
  <path d="M48 56 Q64 48 80 56 V108 Q64 100 48 108 Z" fill="#ffffff" stroke="none"/>
  <path d="M112 56 Q96 48 80 56 V108 Q96 100 112 108 Z" fill="#ffffff" stroke="none"/>
  <line x1="80" y1="56" x2="80" y2="108" stroke="#14B8A6" stroke-width="6"/>'

# file — neutral grey page with folded corner (generic fallback)
badge file "#8A94A6" '
  <path d="M56 40 H92 L112 60 V120 H56 Z" fill="#ffffff" stroke="none"/>
  <path d="M92 40 V60 H112" fill="none" stroke="#8A94A6" stroke-width="6"/>'

# login / key prompt — amber key
badge login "#F59E0B" '
  <circle cx="68" cy="74" r="16" fill="#ffffff" stroke="none"/>
  <circle cx="68" cy="74" r="6" fill="#F59E0B" stroke="none"/>
  <line x1="80" y1="80" x2="116" y2="116" stroke="#ffffff" stroke-width="11"/>
  <line x1="104" y1="104" x2="114" y2="94" stroke="#ffffff" stroke-width="11"/>'

# Native macOS icons for common file extensions.
exts=(pdf doc docx ppt pptx xls xlsx csv numbers pages key txt rtf md json xml \
      zip rar 7z gz tar png jpg jpeg gif heic svg webp psd ai sketch fig \
      mp4 mov avi mkv mp3 wav m4a epub mobi html css js ts py go java apk dmg)
swift - "$out" "${exts[@]}" <<'SWIFT'
import AppKit
let args = CommandLine.arguments
let outDir = args[1]
for ext in args.dropFirst(2) {
    let img = NSWorkspace.shared.icon(forFileType: ext)
    img.size = NSSize(width: 256, height: 256)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try? png.write(to: URL(fileURLWithPath: "\(outDir)/ext-\(ext).png"))
}
SWIFT

echo "Generated $(ls "$out" | wc -l | tr -d ' ') icons in $out/"
