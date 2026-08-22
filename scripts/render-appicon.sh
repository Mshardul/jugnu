#!/bin/bash
set -euo pipefail
# Rasterize Jugnu icon assets for the Xcode asset catalog.
# 128px and above: master SVG. 64 and below: size-ladder-informed scale (see docs/assets).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/shell/App/Assets.xcassets/AppIcon.appiconset"
MB="$ROOT/shell/App/Assets.xcassets/MenuBarIcon.imageset"
MASTER="$ROOT/docs/assets/jugnu-icon.svg"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 "$ROOT/scripts/render-appicon.py" "$TMP/ladder"

render() {
  local svg="$1" size="$2" dest="$3"
  # qlmanage at very small -s pads the thumbnail with white. Rasterize at ≥512, then scale.
  local raster="$size"
  if [ "$size" -lt 128 ]; then
    raster=512
  fi
  local slot="$TMP/$raster-$(basename "$dest")"
  mkdir -p "$slot"
  qlmanage -t -s "$raster" -o "$slot" "$svg" >/dev/null
  local produced
  produced="$(find "$slot" -type f -name '*.png' | head -1)"
  mkdir -p "$(dirname "$dest")"
  sips -s format png -z "$size" "$size" "$produced" --out "$dest" >/dev/null
}

mkdir -p "$OUT" "$MB"
# 64px and below: size-ladder SVGs (tuned geometry), rasterized large then scaled.
# 128px and above: master.
render "$TMP/ladder/jugnu-icon-16.svg" 16 "$OUT/icon_16x16.png"
render "$TMP/ladder/jugnu-icon-32.svg" 32 "$OUT/icon_16x16@2x.png"
render "$TMP/ladder/jugnu-icon-32.svg" 32 "$OUT/icon_32x32.png"
render "$TMP/ladder/jugnu-icon-64.svg" 64 "$OUT/icon_32x32@2x.png"
render "$MASTER" 128 "$OUT/icon_128x128.png"
render "$MASTER" 256 "$OUT/icon_128x128@2x.png"
render "$MASTER" 256 "$OUT/icon_256x256.png"
render "$MASTER" 512 "$OUT/icon_256x256@2x.png"
render "$MASTER" 512 "$OUT/icon_512x512.png"
render "$MASTER" 1024 "$OUT/icon_512x512@2x.png"
cp "$TMP/ladder/MenuBarIcon.png" "$MB/MenuBarIcon.png"

cat > "$OUT/Contents.json" <<'EOF'
{
  "images" : [
    { "idiom" : "mac", "size" : "16x16", "scale" : "1x", "filename" : "icon_16x16.png" },
    { "idiom" : "mac", "size" : "16x16", "scale" : "2x", "filename" : "icon_16x16@2x.png" },
    { "idiom" : "mac", "size" : "32x32", "scale" : "1x", "filename" : "icon_32x32.png" },
    { "idiom" : "mac", "size" : "32x32", "scale" : "2x", "filename" : "icon_32x32@2x.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "1x", "filename" : "icon_128x128.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "2x", "filename" : "icon_128x128@2x.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "1x", "filename" : "icon_256x256.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "2x", "filename" : "icon_256x256@2x.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "1x", "filename" : "icon_512x512.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "2x", "filename" : "icon_512x512@2x.png" }
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
EOF

cat > "$MB/Contents.json" <<'EOF'
{
  "images" : [
    { "idiom" : "mac", "scale" : "2x", "filename" : "MenuBarIcon.png" }
  ],
  "properties" : { "template-rendering-intent" : "template" },
  "info" : { "version" : 1, "author" : "xcode" }
}
EOF

mkdir -p "$ROOT/shell/App/Assets.xcassets"
cat > "$ROOT/shell/App/Assets.xcassets/Contents.json" <<'EOF'
{
  "info" : { "version" : 1, "author" : "xcode" }
}
EOF

echo "Rendered AppIcon and MenuBarIcon into shell/App/Assets.xcassets"
