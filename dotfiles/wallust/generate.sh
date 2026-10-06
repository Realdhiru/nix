#!/usr/bin/env bash
# ==============================================================================
# Self-Contained Wallust Theme Engine
# Usage: ./generate.sh <path-to-wallpaper|--neutral> [dark|light]
# Emits theme files to: ~/.cache/theme/
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CACHE="$HOME/.cache/theme"

mkdir -p "$TARGET_CACHE"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-wallpaper|--neutral> [dark|light]"
    exit 1
fi

WALLPAPER="$1"
MODE="${2:-}"

emit_neutral_theme() {
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
gradient_color_1 = '#42403d'
gradient_color_2 = '#5a5854'
gradient_color_3 = '#736f6a'
gradient_color_4 = '#8b8781'
gradient_color_5 = '#a39f98'
gradient_color_6 = '#bcb6ae'
gradient_color_7 = '#d4cec5'
gradient_color_8 = '#ede6dc'
EOF

    sed 's/{{color4}}/#EDE6DC/g' "$SCRIPT_DIR/templates/gtk.css" > "$TARGET_CACHE/gtk.css"
    # Substitute EVERY placeholder the templates declare. Leaving any
    # {{background}}/{{foreground}}/{{color0}}/{{color8}} raw writes literal
    # braces into live Qt config (unreadable black-on-dark file manager).
    # Values mirror emit_neutral_theme's colors.json (base/text/surfaces).
    sed -e 's/{{color4}}/#EDE6DC/g' -e 's/{{color2}}/#5E5E60/g' -e 's/{{color3}}/#747576/g' -e 's/{{background}}/#000000/g' -e 's/{{foreground}}/#EDE6DC/g' -e 's/{{color0}}/#111116/g' -e 's/{{color8}}/#22222a/g' "$SCRIPT_DIR/templates/qtct.conf" > "$TARGET_CACHE/qtct.conf"
    sed -e 's/{{color4}}/#EDE6DC/g' -e 's/{{background}}/#000000/g' -e 's/{{foreground}}/#EDE6DC/g' -e 's/{{color0}}/#111116/g' -e 's/{{color8}}/#22222a/g' "$SCRIPT_DIR/templates/qt-style.qss" > "$TARGET_CACHE/qt-style.qss"
    cat <<'EOF' > "$TARGET_CACHE/hyprland-colors.conf"
$active_border_col_1 = rgb(EDE6DC)
$active_border_col_2 = rgb(C9BFB5)
$inactive_border_col = rgb(282828)
EOF

    for f in "$HOME/.config/fuzzel/fuzzel.ini" "$HOME/nix/dotfiles/fuzzel/fuzzel.ini"; do
        if [ -f "$f" ]; then
            sed -i -E "s/^(match = ).*/\1EDE6DCff/; s/^(selection-match = ).*/\1EDE6DCff/" "$f" 2>/dev/null || true
        fi
    done
}

# 1. Handle Neutral Theme Mode (pure pitch-black OLED desktop state)
if [ "$WALLPAPER" = "--neutral" ]; then
    emit_neutral_theme

    # Notify client applications.
    # NOTE: never SIGHUP wezterm-gui here — SIGHUP terminates the terminal
    # and kills every pane (including live opencode sessions). Wezterm
    # hot-reloads on config mtime change, so touching the color files
    # (same as the normal path below) is sufficient and non-destructive.
    pkill -USR2 cava 2>/dev/null || true
    touch "$TARGET_CACHE/wezterm-colors.lua" 2>/dev/null || true
    touch "$HOME/nix/dotfiles/wezterm.lua" 2>/dev/null || true
    RESTORE_SCRIPT="$HOME/.config/hypr/scripts/quickshell/restore_state.sh"
    [ ! -x "$RESTORE_SCRIPT" ] && RESTORE_SCRIPT="$HOME/nix/dotfiles/hypr/scripts/quickshell/restore_state.sh"
    if [ -x "$RESTORE_SCRIPT" ]; then "$RESTORE_SCRIPT" >/dev/null 2>&1 || true; fi
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

# For animated formats (GIFs), restrict input to the first frame [0]
# to prevent ImageMagick from iterating over all frames in the animation.
WALL_INPUT="$WALLPAPER"
WALL_LOWER="${WALLPAPER,,}"
if [[ "$WALL_LOWER" == *.gif ]]; then
    WALL_INPUT="${WALLPAPER}[0]"
fi

# 1. Compute luminance metrics directly from the wallpaper (downsampled for instant execution)
OVERALL_LUM="50"
TOP_LUM="50"
if command -v magick >/dev/null 2>&1; then
    OVERALL_LUM=$(magick "$WALL_INPUT" -resize 128x128\! -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
    TOP_LUM=$(magick "$WALL_INPUT" -resize 128x128\! -gravity North -crop 128x13+0+0 +repage -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
elif command -v convert >/dev/null 2>&1; then
    OVERALL_LUM=$(convert "$WALL_INPUT" -resize 128x128\! -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
    TOP_LUM=$(convert "$WALL_INPUT" -resize 128x128\! -gravity North -crop 128x13+0+0 +repage -colorspace Gray -format "%[fx:mean*100]" info: 2>/dev/null || echo "50")
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
    COLOR_DATA=$(magick "$WALL_INPUT" -depth 8 -scale 100x100 -colors 16 -format "%c\n" histogram:info: 2>/dev/null | python3 -c '
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

total_pixels = sum(p[0] for p in parsed) or 1
dark_or_mono_pixels = sum(p[0] for p in parsed if p[4] < 0.12 or p[3] < 0.12)
colored = [p for p in parsed if p[3] >= 0.15 and 0.10 <= p[4] <= 0.85]
colored_pixels = sum(p[0] for p in colored)

# If image is >= 80% black/dark or colored pixels represent less than 4% of image:
if colored and (dark_or_mono_pixels / total_pixels) < 0.80 and (colored_pixels / total_pixels) >= 0.04:
    is_mono = "False"
    colored.sort(key=lambda p: (p[0] ** 0.7) * (1.0 + p[3] * 1.5), reverse=True)
    best = colored[0]
    target_l = 0.38 if mode == "light" else 0.68
    target_s = max(0.65 if mode == "light" else 0.55, min(0.90, best[3] * 1.25))
    r, g, b = colorsys.hls_to_rgb(best[2], target_l, target_s)
    accent = "#{0:02x}{1:02x}{2:02x}".format(int(r*255), int(g*255), int(b*255))
else:
    is_mono = "True"
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

# 3. Apply Theme: if monochrome / dark-dominated, emit clean neutral OLED palette
if [ "$IS_MONO" = "True" ]; then
    emit_neutral_theme
else
    PALETTE="saliencedark16"
    COLORSPACE="salience"
    if [ "$MODE" = "light" ]; then
        PALETTE="light16"
        COLORSPACE="lch"
    fi

    if ! wallust run \
        --config-dir "$SCRIPT_DIR" \
        --palette "$PALETTE" \
        --colorspace "$COLORSPACE" \
        --check-contrast \
        -s \
        -q \
        "$WALLPAPER" 2>/dev/null; then
        emit_neutral_theme
    fi
fi

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
    mv "$TARGET_CACHE/colors.json.tmp" "$TARGET_CACHE/colors.json"
fi

# 5. Inject dynamic wallpaper palette into GTK, Qt, WezTerm, and Cava
if [ -n "$ACCENT" ]; then
    BG=$(jq -r '.base // "#121318"' "$TARGET_CACHE/colors.json" 2>/dev/null || echo "#121318")
    FG=$(jq -r '.text // "#EDE6DC"' "$TARGET_CACHE/colors.json" 2>/dev/null || echo "#EDE6DC")
    SURF0=$(jq -r '.surface0 // "#16171f"' "$TARGET_CACHE/colors.json" 2>/dev/null || echo "#16171f")
    SURF1=$(jq -r '.surface1 // "#2b2d3a"' "$TARGET_CACHE/colors.json" 2>/dev/null || echo "#2b2d3a")

    sed "s/{{color4}}/$ACCENT/g" "$SCRIPT_DIR/templates/gtk.css" > "$TARGET_CACHE/gtk.css"

    sed -e "s/{{color4}}/$ACCENT/g" \
        -e "s/{{color2}}/${SUBTEXT0:-#5E5E60}/g" \
        -e "s/{{color3}}/${SUBTEXT1:-#747576}/g" \
        -e "s/{{background}}/${BG}/g" \
        -e "s/{{foreground}}/${FG}/g" \
        -e "s/{{color0}}/${SURF0}/g" \
        -e "s/{{color8}}/${SURF1}/g" \
        "$SCRIPT_DIR/templates/qtct.conf" > "$TARGET_CACHE/qtct.conf"

    sed -e "s/{{color4}}/$ACCENT/g" \
        -e "s/{{color2}}/${SUBTEXT0:-#5E5E60}/g" \
        -e "s/{{color3}}/${SUBTEXT1:-#747576}/g" \
        -e "s/{{background}}/${BG}/g" \
        -e "s/{{foreground}}/${FG}/g" \
        -e "s/{{color0}}/${SURF0}/g" \
        -e "s/{{color8}}/${SURF1}/g" \
        "$SCRIPT_DIR/templates/qt-style.qss" > "$TARGET_CACHE/qt-style.qss"

    cat <<EOF > "$TARGET_CACHE/hyprland-colors.conf"
\$active_border_col_1 = rgb(${ACCENT#'#'})
\$active_border_col_2 = rgb(${SUBTEXT0#'#'})
\$inactive_border_col = rgb(282828)
EOF

    if [ -f "$TARGET_CACHE/wezterm-colors.lua" ]; then
        sed -i "s/cursor_bg = \".*\"/cursor_bg = \"$ACCENT\"/" "$TARGET_CACHE/wezterm-colors.lua"
        sed -i "s/cursor_border = \".*\"/cursor_border = \"$ACCENT\"/" "$TARGET_CACHE/wezterm-colors.lua"
        sed -i "s/selection_bg = \".*\"/selection_bg = \"$ACCENT\"/" "$TARGET_CACHE/wezterm-colors.lua"
    fi

    if [ -d "$HOME/.config/cava/themes" ]; then
        python3 -c '
import sys
c = sys.argv[1].lstrip("#")
if len(c) >= 6:
    r, g, b = int(c[0:2], 16)/255.0, int(c[2:4], 16)/255.0, int(c[4:6], 16)/255.0
    print("[color]\ngradient = 1\ngradient_count = 8")
    for i in range(8):
        t = 0.28 + (0.72 * (i / 7.0))
        print(f"gradient_color_{i+1} = \"#{int(r * t * 255):02x}{int(g * t * 255):02x}{int(b * t * 255):02x}\"")
' "$ACCENT" > "$HOME/.config/cava/themes/wallust" 2>/dev/null || true
    fi

    HEX_ACCENT="${ACCENT#'#'}"
    for f in "$HOME/.config/fuzzel/fuzzel.ini" "$HOME/nix/dotfiles/fuzzel/fuzzel.ini"; do
        if [ -f "$f" ]; then
            sed -i -E "s/^(match = ).*/\1${HEX_ACCENT}ff/; s/^(selection-match = ).*/\1${HEX_ACCENT}ff/" "$f" 2>/dev/null || true
        fi
    done
fi

# Notify client applications if running
pkill -USR2 cava 2>/dev/null || true
touch "$TARGET_CACHE/wezterm-colors.lua" 2>/dev/null || true
touch "$HOME/nix/dotfiles/wezterm.lua" 2>/dev/null || true
RESTORE_SCRIPT="$HOME/.config/hypr/scripts/quickshell/restore_state.sh"
[ ! -x "$RESTORE_SCRIPT" ] && RESTORE_SCRIPT="$HOME/nix/dotfiles/hypr/scripts/quickshell/restore_state.sh"
if [ -x "$RESTORE_SCRIPT" ]; then "$RESTORE_SCRIPT" >/dev/null 2>&1 || true; fi
if command -v quickshell >/dev/null 2>&1; then
    quickshell ipc -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" call main reloadTheme >/dev/null 2>&1 || true
fi
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita:dark" >/dev/null 2>&1 || true
    if [ -n "${ACCENT:-}" ]; then
        GNOME_ACCENT=$(python3 -c '
import sys, colorsys
c = sys.argv[1].lstrip("#")
if len(c) >= 6:
    r, g, b = int(c[0:2], 16)/255.0, int(c[2:4], 16)/255.0, int(c[4:6], 16)/255.0
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if s < 0.15:
        print("slate")
    elif h < 0.05 or h >= 0.95:
        print("red")
    elif h < 0.12:
        print("orange")
    elif h < 0.20:
        print("yellow")
    elif h < 0.45:
        print("green")
    elif h < 0.55:
        print("teal")
    elif h < 0.70:
        print("blue")
    elif h < 0.82:
        print("purple")
    else:
        print("pink")
else:
    print("purple")
' "$ACCENT" 2>/dev/null || echo "purple")
        gsettings set org.gnome.desktop.interface accent-color "$GNOME_ACCENT" >/dev/null 2>&1 || true
    fi
fi
