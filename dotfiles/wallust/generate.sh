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

# 1. Handle Neutral Theme Mode (pure pitch-black OLED desktop state)
if [ "$WALLPAPER" = "--neutral" ]; then
    cat <<'EOF' > "$TARGET_CACHE/colors.json"
{
  "base": "#000000",
  "mantle": "#000000",
  "crust": "#000000",
  "surface0": "#111116",
  "surface1": "#181820",
  "surface2": "#22222a",
  "overlay0": "#6c7086",
  "overlay1": "#7f849c",
  "overlay2": "#9399b2",
  "text": "#EDE6DC",
  "subtext0": "#C9BFB5",
  "subtext1": "#A89F95",
  "blue": "#7E7E7F",
  "sapphire": "#8B8C8E",
  "peach": "#828284",
  "green": "#5E5E60",
  "red": "#484849",
  "mauve": "#EDE6DC",
  "pink": "#B4B5B7",
  "yellow": "#747576",
  "maroon": "#4C4D4F",
  "teal": "#ADADAF",
  "isLight": false,
  "topLuminance": 0.0,
  "primary": "#EDE6DC"
}
EOF

    cat <<'EOF' > "$TARGET_CACHE/wezterm-colors.lua"
return {
    foreground = "#EDE6DC",
    background = "#000000",

    cursor_bg = "#EDE6DC",
    cursor_fg = "#000000",
    cursor_border = "#EDE6DC",

    selection_bg = "#313131",
    selection_fg = "#EDE6DC",

    ansi = {
        "#151515",  -- Black
        "#484849",  -- Red
        "#5E5E60",  -- Green
        "#747576",  -- Yellow
        "#7E7E7F",  -- Blue
        "#878889",  -- Magenta
        "#ADADAF",  -- Cyan
        "#EAEBEC"   -- White
    },

    brights = {
        "#404040",  -- Bright Black
        "#4C4D4F",  -- Bright Red
        "#6A6A6C",  -- Bright Green
        "#828284",  -- Bright Yellow
        "#8B8C8E",  -- Bright Blue
        "#B4B5B7",  -- Bright Magenta
        "#E6E7E9",  -- Bright Cyan
        "#FFFFFF"   -- Bright White
    }
}
EOF

    mkdir -p "$HOME/.config/cava/themes"
    cat <<'EOF' > "$HOME/.config/cava/themes/wallust"
[color]
gradient = 1
gradient_count = 8
gradient_color_1 = '#EDE6DC'
gradient_color_2 = '#D4D4D8'
gradient_color_3 = '#A1A1AA'
gradient_color_4 = '#71717A'
gradient_color_5 = '#52525B'
gradient_color_6 = '#3F3F46'
gradient_color_7 = '#27272A'
gradient_color_8 = '#18181B'
EOF

    sed 's/{{color4}}/#EDE6DC/g' "$SCRIPT_DIR/templates/gtk.css" > "$TARGET_CACHE/gtk.css"
    sed -e 's/{{color4}}/#EDE6DC/g' -e 's/{{color2}}/#5E5E60/g' -e 's/{{color3}}/#747576/g' "$SCRIPT_DIR/templates/qtct.conf" > "$TARGET_CACHE/qtct.conf"
    sed 's/{{color4}}/#EDE6DC/g' "$SCRIPT_DIR/templates/qt-style.qss" > "$TARGET_CACHE/qt-style.qss"
    cat <<'EOF' > "$TARGET_CACHE/hyprland-colors.conf"
$active_border_col_1 = rgb(EDE6DC)
$active_border_col_2 = rgb(C9BFB5)
$inactive_border_col = rgb(282828)
EOF

    # Backward compatibility symlinks
    ln -sf "$TARGET_CACHE/colors.json" "$MATUGEN_COMPAT/qs_colors.json"
    ln -sf "$TARGET_CACHE/wezterm-colors.lua" "$MATUGEN_COMPAT/wezterm-colors.lua"
    ln -sf "$TARGET_CACHE/gtk.css" "$MATUGEN_COMPAT/gtk.css"
    ln -sf "$TARGET_CACHE/qtct.conf" "$MATUGEN_COMPAT/qtct.conf"
    ln -sf "$TARGET_CACHE/qt-style.qss" "$MATUGEN_COMPAT/qt-style.qss"

    # Notify client applications
    pkill -USR2 cava 2>/dev/null || true
    pkill -HUP wezterm-gui 2>/dev/null || true
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
    if command -v quickshell >/dev/null 2>&1; then
        quickshell ipc -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" call main reloadTheme >/dev/null 2>&1 || true
    fi
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface gtk-theme "Adwaita" >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface gtk-theme "Adwaita:dark" >/dev/null 2>&1 || true
    fi
    exit 0
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
    MODE="$SETTING_MODE"
fi
IS_LIGHT_VAL=$([ "$MODE" = "light" ] && echo "true" || echo "false")

# 2. Extract true dominant, vibrant accent color from wallpaper
COLOR_DATA=""
if command -v magick >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    COLOR_DATA=$(magick "$WALLPAPER" -depth 8 -scale 100x100 -colors 16 -format "%c\n" histogram:info: 2>/dev/null | python3 -c '
import sys, re, colorsys
mode = sys.argv[1] if len(sys.argv) > 1 else "dark"
lines = sys.stdin.readlines()
parsed = []
for line in lines:
    m = re.search(r"(\d+):\s*\(.*?\)\s*#([0-9A-Fa-f]+)", line)
    if m:
        count = int(m.group(1))
        hstr = m.group(2)
        if len(hstr) >= 12:
            r = int(hstr[0:4], 16) / 65535.0
            g = int(hstr[4:8], 16) / 65535.0
            b = int(hstr[8:12], 16) / 65535.0
        elif len(hstr) >= 6:
            r = int(hstr[0:2], 16) / 255.0
            g = int(hstr[2:4], 16) / 255.0
            b = int(hstr[4:6], 16) / 255.0
        else:
            continue
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        hex_c = "#{0:02x}{1:02x}{2:02x}".format(int(r*255), int(g*255), int(b*255))
        parsed.append((count, hex_c, h, s, l))

colored = [p for p in parsed if p[3] >= 0.15 and 0.10 <= p[4] <= 0.85]
if colored:
    is_mono = "False"
    colored.sort(key=lambda p: (p[0] ** 0.7) * (1.0 + p[3] * 1.5), reverse=True)
    best = colored[0]
    target_l = 0.38 if mode == "light" else 0.68
    target_s = max(0.65 if mode == "light" else 0.55, min(0.90, best[3] * 1.25))
    r, g, b = colorsys.hls_to_rgb(best[2], target_l, target_s)
    accent = "#{0:02x}{1:02x}{2:02x}".format(int(r*255), int(g*255), int(b*255))
else:
    is_mono = "True"
    # Pure monochrome wallpaper: clean radiant silver/platinum accent (never false blue)
    accent = "#EDE6DC" if mode == "dark" else "#2D3139"

if mode == "light":
    text_color = "#181926"
    subtext0 = "#494d64"
    subtext1 = "#5b6078"
else:
    text_color = "#EDE6DC"
    subtext0 = "#C9BFB5"
    subtext1 = "#A89F95"

print(f"{accent}|{text_color}|{subtext0}|{subtext1}|{is_mono}")
' "$MODE" 2>/dev/null || true)
fi

ACCENT=""
TEXT_COLOR=""
SUBTEXT0=""
SUBTEXT1=""
IS_MONO="False"
if [ -n "$COLOR_DATA" ]; then
    IFS="|" read -r ACCENT TEXT_COLOR SUBTEXT0 SUBTEXT1 IS_MONO <<< "$COLOR_DATA"
fi

# 3. Run Wallust with dynamic wallpaper-extracted ANSI palette
# If monochrome, use clean dark16 + lch to prevent false rainbow ANSI synthesis
if [ "$IS_MONO" = "True" ]; then
    PALETTE="dark16"
    COLORSPACE="lch"
else
    PALETTE="ansidark16"
    COLORSPACE="lchansi"
fi
if [ "$MODE" = "light" ]; then
    PALETTE="light16"
    COLORSPACE="lch"
fi

wallust run \
    --config-dir "$SCRIPT_DIR" \
    --palette "$PALETTE" \
    --colorspace "$COLORSPACE" \
    --check-contrast \
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

# 5. Inject dynamic wallpaper accent into GTK, Qt stylesheets and Qt color palette
if [ -n "$ACCENT" ]; then
    sed "s/{{color4}}/$ACCENT/g" "$SCRIPT_DIR/templates/gtk.css" > "$TARGET_CACHE/gtk.css"
    sed -e "s/{{color4}}/$ACCENT/g" -e "s/{{color2}}/${SUBTEXT0:-#5E5E60}/g" -e "s/{{color3}}/${SUBTEXT1:-#747576}/g" "$SCRIPT_DIR/templates/qtct.conf" > "$TARGET_CACHE/qtct.conf"
    sed "s/{{color4}}/$ACCENT/g" "$SCRIPT_DIR/templates/qt-style.qss" > "$TARGET_CACHE/qt-style.qss"
    cat <<EOF > "$TARGET_CACHE/hyprland-colors.conf"
\$active_border_col_1 = rgb(${ACCENT#'#'})
\$active_border_col_2 = rgb(${SUBTEXT0#'#'})
\$inactive_border_col = rgb(282828)
EOF
fi

# Backward compatibility symlinks for apps expecting legacy paths
ln -sf "$TARGET_CACHE/colors.json" "$MATUGEN_COMPAT/qs_colors.json"
ln -sf "$TARGET_CACHE/wezterm-colors.lua" "$MATUGEN_COMPAT/wezterm-colors.lua"
ln -sf "$TARGET_CACHE/gtk.css" "$MATUGEN_COMPAT/gtk.css"
ln -sf "$TARGET_CACHE/qtct.conf" "$MATUGEN_COMPAT/qtct.conf"
ln -sf "$TARGET_CACHE/qt-style.qss" "$MATUGEN_COMPAT/qt-style.qss"

# Notify client applications if running
pkill -USR2 cava 2>/dev/null || true
pkill -HUP wezterm-gui 2>/dev/null || true
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
fi
if command -v quickshell >/dev/null 2>&1; then
    quickshell ipc -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" call main reloadTheme >/dev/null 2>&1 || true
fi
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita:dark" >/dev/null 2>&1 || true
fi
