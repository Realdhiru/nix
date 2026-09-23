#!/usr/bin/env bash
# ==============================================================================
# Self-Contained Wallust Theme Engine
# Usage: ./generate.sh <path-to-wallpaper|--neutral> [dark|light]
# Emits theme files to: ~/.cache/theme/
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CACHE="$HOME/.cache/theme"
MATUGEN_COMPAT="$HOME/.cache/matugen"

mkdir -p "$TARGET_CACHE" "$MATUGEN_COMPAT"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-wallpaper|--neutral> [dark|light]"
    exit 1
fi

WALLPAPER="$1"
MODE="${2:-}"

# 1. Handle Neutral Theme Mode (e.g. killed wallpaper or neutral desktop state)
if [ "$WALLPAPER" = "--neutral" ]; then
    NEUTRAL_SEED="/tmp/wallust_neutral_seed.png"
    if command -v magick >/dev/null 2>&1; then
        magick -size 64x64 gradient:"#181926-#363a4f" "$NEUTRAL_SEED"
    elif command -v convert >/dev/null 2>&1; then
        convert -size 64x64 gradient:"#181926-#363a4f" "$NEUTRAL_SEED"
    else
        python3 -c '
import struct, zlib
def create_png():
    w, h = 64, 64
    raw = b"\x00" + b"\x24\x27\x30" * w
    data = raw * h
    c = zlib.compress(data)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    def chk(t, b): return struct.pack(">I", len(b)) + t + b + struct.pack(">I", zlib.crc32(t + b) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chk(b"IHDR", ihdr) + chk(b"IDAT", c) + chk(b"IEND", b"")
open("'"$NEUTRAL_SEED"'", "wb").write(create_png())
' 2>/dev/null || true
    fi
    WALLPAPER="$NEUTRAL_SEED"
    MODE="dark"
fi

if [ ! -f "$WALLPAPER" ]; then
    echo "Error: Image not found: $WALLPAPER" >&2
    exit 1
fi

if [ -z "$MODE" ]; then
    if [ -f "$TARGET_CACHE/is_light.txt" ]; then
        IS_LIGHT="$(cat "$TARGET_CACHE/is_light.txt" 2>/dev/null || echo "false")"
        [ "$IS_LIGHT" = "true" ] && MODE="light" || MODE="dark"
    else
        MODE="dark"
    fi
fi

# Run Wallust with high-vibrancy K-Means clustering and Lch colorspace
PALETTE="harddark16"
if [ "$MODE" = "light" ]; then
    PALETTE="light16"
fi

wallust run \
    --config-dir "$SCRIPT_DIR" \
    --palette "$PALETTE" \
    -q \
    "$WALLPAPER"

# Compute luminance metrics for adaptive UI contrast (QuickShell)
if [ -f "$TARGET_CACHE/colors.json" ]; then
    OVERALL_LUM="50"
    TOP_LUM="50"
    if command -v magick >/dev/null 2>&1; then
        OVERALL_LUM=$(magick "$WALLPAPER" -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
        TOP_LUM=$(magick "$WALLPAPER" -gravity North -crop 100x10%+0+0 -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
    elif command -v convert >/dev/null 2>&1; then
        OVERALL_LUM=$(convert "$WALLPAPER" -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
        TOP_LUM=$(convert "$WALLPAPER" -gravity North -crop 100x10%+0+0 -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
    fi

    IS_LIGHT_VAL=$(awk -v l="$OVERALL_LUM" 'BEGIN {print (l > 65) ? "true" : "false"}')
    TOP_LUM_VAL=$(awk -v l="$TOP_LUM" 'BEGIN {printf "%.1f", l}')

    # Merge metadata into colors.json atomically
    jq --argjson il "$IS_LIGHT_VAL" --arg tl "$TOP_LUM_VAL" \
        '. + {isLight: $il, topLuminance: ($tl|tonumber)}' \
        "$TARGET_CACHE/colors.json" > "$TARGET_CACHE/colors.json.tmp" 2>/dev/null && \
    mv -f "$TARGET_CACHE/colors.json.tmp" "$TARGET_CACHE/colors.json"

    echo "$IS_LIGHT_VAL" > "$TARGET_CACHE/is_light.txt"
fi

# Backward compatibility symlinks for apps expecting legacy paths
ln -sf "$TARGET_CACHE/colors.json" "$MATUGEN_COMPAT/qs_colors.json"
ln -sf "$TARGET_CACHE/wezterm-colors.lua" "$MATUGEN_COMPAT/wezterm-colors.lua"
ln -sf "$TARGET_CACHE/gtk.css" "$MATUGEN_COMPAT/gtk.css"
ln -sf "$TARGET_CACHE/qtct.conf" "$MATUGEN_COMPAT/qtct.conf"
ln -sf "$TARGET_CACHE/qt-style.qss" "$MATUGEN_COMPAT/qt-style.qss"

# Notify client applications if running
pkill -USR2 cava 2>/dev/null || true
if command -v wezterm >/dev/null 2>&1; then
    wezterm cli reload-configuration 2>/dev/null || true
fi
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
fi
