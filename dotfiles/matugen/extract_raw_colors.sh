#!/usr/bin/env bash
# Extract a raw, wallpaper-matched palette into qs_colors.json.
#
# Colors are taken literally from the image (quantized, no Material
# tone-mapping), so accents always match the wallpaper: darkest tone becomes
# the background, the brightest saturated tone the primary accent, etc.
# Fails cleanly WITHOUT touching the current palette if extraction fails
# (a broken run must never clobber a good palette with junk).

WALL="$1"
CACHE_FILE="$HOME/.cache/matugen/qs_colors.json"

if [ -z "$WALL" ] || [ ! -f "$WALL" ]; then
    exit 1
fi

HISTO=$(mktemp)
trap 'rm -f "$HISTO"' EXIT

if ! magick "$WALL" -resize 200x -colors 8 -depth 8 -format "%c" histogram:info:- > "$HISTO" 2>/dev/null; then
    exit 1
fi

HEXES=$(awk '{print $3}' "$HISTO" | tr '\n' ' ')
[ -n "$HEXES" ] || exit 1

python3 - "$CACHE_FILE" $HEXES <<'EOF'
import json, sys, os, colorsys

cache = sys.argv[1]

cols = []
for h in sys.argv[2:]:
    h = h.strip().lstrip("#")
    if len(h) >= 6:
        r, g, b = int(h[:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        cols.append((r, g, b, "#" + h[:6].upper()))

if len(cols) < 2:
    sys.exit(1)

def lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]

def sat(c):
    return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)[1]

cols.sort(key=lum)
base = cols[0][3]
m2 = cols[1][3] if len(cols) > 1 else base
m3 = cols[2][3] if len(cols) > 2 else m2
m4 = cols[3][3] if len(cols) > 3 else m3

cream = max(cols, key=lum)[3]

bright = [c for c in cols[1:] if lum(c) > 0.30 * 255]
primary = max(bright, key=sat)[3] if bright else max(cols[1:], key=sat)[3]

light = [c for c in cols[1:] if lum(c) > 0.35 * 255]
secondary = max(light, key=sat)[3] if light else primary

dark_warm = [c for c in cols[1:] if lum(c) < 0.45 * 255 and c[3] != primary]
red = max(dark_warm, key=sat)[3] if dark_warm else primary

pal = {
    "base": base,
    "mantle": m2,
    "crust": m3,
    "text": "#ffffff",
    "subtext0": cream,
    "subtext1": cream,
    "surface0": m2,
    "surface1": m3,
    "surface2": m4,
    "overlay0": m4,
    "overlay1": cream,
    "overlay2": "#ffffff",
    "blue": primary,
    "sapphire": primary,
    "peach": primary,
    "green": secondary,
    "red": red,
    "mauve": primary,
    "pink": primary,
    "yellow": primary,
    "maroon": red,
    "teal": secondary,
}

tmp = cache + ".tmp"
with open(tmp, "w") as f:
    json.dump(pal, f, indent=2)
os.replace(tmp, cache)
EOF