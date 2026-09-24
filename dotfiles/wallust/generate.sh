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

# 1. Compute luminance metrics directly from the wallpaper
OVERALL_LUM="50"
TOP_LUM="50"
if command -v magick >/dev/null 2>&1; then
    OVERALL_LUM=$(magick "$WALLPAPER" -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
    TOP_LUM=$(magick "$WALLPAPER" -gravity North -crop 100x10%+0+0 -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
elif command -v convert >/dev/null 2>&1; then
    OVERALL_LUM=$(convert "$WALLPAPER" -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
    TOP_LUM=$(convert "$WALLPAPER" -gravity North -crop 100x10%+0+0 -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
fi

TOP_LUM_VAL=$(awk -v l="$TOP_LUM" 'BEGIN {printf "%.1f", l}')

# Determine theme mode: strictly manual from settings.json ("dark" | "light") or CLI argument.
# Default is ALWAYS "dark" regardless of wallpaper lightness.
SETTINGS_FILE="$HOME/.config/hypr/settings.json"
SETTING_MODE="dark"
if [ -f "$SETTINGS_FILE" ]; then
    SETTING_MODE=$(jq -r '.themeMode // "dark"' "$SETTINGS_FILE" 2>/dev/null || echo "dark")
fi
if [ -z "$MODE" ]; then
    # Mode options: "dark" (default, rich dark glass) | "light" (clean light paper)
    MODE="$SETTING_MODE"
fi
IS_LIGHT_VAL=$([ "$MODE" = "light" ] && echo "true" || echo "false")

# 2. Extract true dominant, vibrant accent color from wallpaper
COLOR_DATA=""
if command -v magick >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    COLOR_DATA=$(magick "$WALLPAPER" -scale 100x100 -colors 16 -format "%c\n" histogram:info: 2>/dev/null | python3 -c '
import sys, re, colorsys
mode = sys.argv[1] if len(sys.argv) > 1 else "dark"
lines = sys.stdin.readlines()
parsed = []
for line in lines:
    m = re.search(r"(\d+):\s*\(.*?\)\s*(#[0-9A-Fa-f]{6})", line)
    if m:
        hex_c = m.group(2)
        r, g, b = int(hex_c[1:3], 16)/255.0, int(hex_c[3:5], 16)/255.0, int(hex_c[5:7], 16)/255.0
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        parsed.append((int(m.group(1)), hex_c, h, s, l))

colored = [p for p in parsed if p[3] >= 0.15 and 0.10 <= p[4] <= 0.85]
if colored:
    # Harmonic scoring: balances pixel frequency with saturation (avoids isolated tiny red dots)
    colored.sort(key=lambda p: (p[0] ** 0.7) * (1.0 + p[3] * 1.5), reverse=True)
    best = colored[0]
    target_l = 0.38 if mode == "light" else 0.68
    target_s = max(0.65 if mode == "light" else 0.55, min(0.90, best[3] * 1.25))
    r, g, b = colorsys.hls_to_rgb(best[2], target_l, target_s)
    accent = "#{0:02x}{1:02x}{2:02x}".format(int(r*255), int(g*255), int(b*255))
else:
    accent = "#8caaee"

# High-contrast, clean neutral text
if mode == "light":
    text_color = "#181926"
    subtext0 = "#494d64"
    subtext1 = "#5b6078"
else:
    text_color = "#EDE6DC"  # Soft warm ivory / cream (high contrast, zero red tint)
    subtext0 = "#C9BFB5"
    subtext1 = "#A89F95"

print(f"{accent}|{text_color}|{subtext0}|{subtext1}")
' "$MODE" 2>/dev/null || true)
fi

ACCENT=""
TEXT_COLOR=""
SUBTEXT0=""
SUBTEXT1=""
if [ -n "$COLOR_DATA" ]; then
    IFS="|" read -r ACCENT TEXT_COLOR SUBTEXT0 SUBTEXT1 <<< "$COLOR_DATA"
fi

# 3. Run Wallust with high-vibrancy salience palette
# Palette options: "saliencedark16" (dark mode), "saliencelight16" (light mode)
PALETTE="saliencedark16"
if [ "$MODE" = "light" ]; then
    PALETTE="saliencelight16"
fi

wallust run \
    --config-dir "$SCRIPT_DIR" \
    --palette "$PALETTE" \
    --colorspace salience \
    -s \
    -q \
    "$WALLPAPER"

# 4. Merge metadata & vibrant accent into colors.json in-place
if [ -f "$TARGET_CACHE/colors.json" ]; then
    jq --argjson il "$IS_LIGHT_VAL" --arg tl "$TOP_LUM_VAL" --arg ac "$ACCENT" --arg tx "$TEXT_COLOR" --arg s0 "$SUBTEXT0" --arg s1 "$SUBTEXT1" \
        '. + {
            isLight: $il,
            topLuminance: ($tl|tonumber),
            mauve: (if $ac != "" then $ac else .mauve end),
            primary: (if $ac != "" then $ac else .mauve end),
            text: (if $tx != "" then $tx else .text end),
            subtext0: (if $s0 != "" then $s0 else .subtext0 end),
            subtext1: (if $s1 != "" then $s1 else .subtext1 end),
            overlay0: "#6c7086",
            overlay1: "#7f849c",
            overlay2: "#9399b2"
        }' \
        "$TARGET_CACHE/colors.json" > "$TARGET_CACHE/colors.json.tmp" 2>/dev/null && \
    cat "$TARGET_CACHE/colors.json.tmp" > "$TARGET_CACHE/colors.json" && \
    rm -f "$TARGET_CACHE/colors.json.tmp"
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
if command -v quickshell >/dev/null 2>&1; then
    quickshell ipc -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" call main reloadTheme >/dev/null 2>&1 || true
fi
