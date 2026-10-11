#!/usr/bin/env bash
# ==============================================================================
# Self-Contained Wallust Theme Engine
# Usage: ./generate.sh <path-to-wallpaper|--neutral> [dark|light]
# Emits theme files to: ~/.cache/theme/
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/terminal-opacity.sh"
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
  "primary": "#EDE6DC",
  "accent": "#EDE6DC",
  "background": "#000000",
  "foreground": "#EDE6DC",
  "opacity": 1.0,
  "cursor_bg": "#EDE6DC",
  "cursor_fg": "#000000",
  "cursor_border": "#EDE6DC",
  "selection_bg": "#313131",
  "selection_fg": "#EDE6DC",
  "active_border_1": "#EDE6DC",
  "active_border_2": "#C9BFB5",
  "inactive_border": "#151515",
  "ansi": [
    "#151515",
    "#484849",
    "#5E5E60",
    "#747576",
    "#7E7E7F",
    "#878889",
    "#ADADAF",
    "#EAEBEC"
  ],
  "brights": [
    "#404040",
    "#4C4D4F",
    "#6A6A6C",
    "#828284",
    "#8B8C8E",
    "#B4B5B7",
    "#E6E7E9",
    "#FFFFFF"
  ]
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
            sed -i -E "s/^(match = ).*/\1EDE6DCff/; s/^(selection-match = ).*/\1EDE6DCff/; s/^(background = ).*/\1000000ff/" "$f" 2>/dev/null || true
        fi
    done

    apply_terminal_opacity
}

# 1. Handle Neutral Theme Mode (pure pitch-black OLED desktop state)
if [ "$WALLPAPER" = "--neutral" ]; then
    emit_neutral_theme

    # Notify client applications.
    pkill -USR2 cava 2>/dev/null || true
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

# 2. Run Wallust natively to generate all template outputs
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
apply_terminal_opacity

# 3. Read generated palette and select the true signature wallpaper accent
# Uses direct ImageMagick quantization histogram to capture the authentic dominant chromatic tone
RAW_HIST=$(magick "$WALL_INPUT" -resize 64x64\! -colors 16 -format "%c" histogram:info: 2>/dev/null || true)

ACCENT=$(echo "$RAW_HIST" | awk '
function hex2hsl(h,   r, g, b, max, min, d, hue, sat, lum) {
    h = substr(h, 2);
    r = strtonum("0x" substr(h, 1, 2)) / 255.0;
    g = strtonum("0x" substr(h, 3, 2)) / 255.0;
    b = strtonum("0x" substr(h, 5, 2)) / 255.0;
    max = (r > g) ? ((r > b) ? r : b) : ((g > b) ? g : b);
    min = (r < g) ? ((r < b) ? r : b) : ((g < b) ? g : b);
    lum = (max + min) / 2.0;
    if (max == min) { hue = 0; sat = 0; }
    else {
        d = max - min;
        sat = lum > 0.5 ? d / (2.0 - max - min) : d / (max + min);
        if (max == r) hue = (g - b) / d + (g < b ? 6 : 0);
        else if (max == g) hue = (b - r) / d + 2;
        else hue = (r - g) / d + 4;
        hue /= 6.0;
    }
    return hue " " sat " " lum;
}
function hsl2rgb(h, s, l,   q, p, c, t, i) {
    q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
    p = 2.0 * l - q;
    for (i = 1; i <= 3; i++) {
        t = (i == 1) ? h + 1.0/3.0 : ((i == 2) ? h : h - 1.0/3.0);
        if (t < 0) t += 1.0;
        if (t > 1) t -= 1.0;
        if (t < 1.0/6.0) c[i] = p + (q - p) * 6.0 * t;
        else if (t < 1.0/2.0) c[i] = q;
        else if (t < 2.0/3.0) c[i] = p + (q - p) * (2.0/3.0 - t) * 6.0;
        else c[i] = p;
    }
    return sprintf("#%02X%02X%02X", int(c[1]*255 + 0.5), int(c[2]*255 + 0.5), int(c[3]*255 + 0.5));
}
BEGIN {
    total_sat = 0;
    total_cnt = 0;
    n = 0;
}
{
    match($0, /#[0-9A-Fa-f]{6}/);
    if (RSTART > 0) {
        hex_arr[n] = substr($0, RSTART, RLENGTH);
        cnt_arr[n] = $1 + 0;
        split(hex2hsl(hex_arr[n]), hsl, " ");
        h_arr[n] = hsl[1];
        s_arr[n] = hsl[2];
        l_arr[n] = hsl[3];
        total_sat += s_arr[n] * cnt_arr[n];
        total_cnt += cnt_arr[n];
        n++;
    }
}
END {
    avg_sat = (total_cnt > 0) ? (total_sat / total_cnt) : 0;
    best_score = -1;
    best_idx = -1;

    # Evaluate each palette color using coverage-weighted atmospheric dominance
    for (i = 0; i < n; i++) {
        cov = (total_cnt > 0) ? (cnt_arr[i] / total_cnt) : 0;
        cl = l_arr[i];
        cs = s_arr[i];

        # Exclude deep void shadows (< 0.20) and extreme white highlights (> 0.90)
        if (cl >= 0.20 && cl <= 0.90) {
            cov_factor = (cnt_arr[i] ^ 0.60);
            # Reward chromatic identity over dead neutral gray:
            chroma_factor = (cs >= 0.025) ? (cs ^ 0.40) : (cs * 5.0);
            # Ideal midtone luminance for UI legibility:
            lum_factor = 1.0 - (cl - 0.52) * (cl - 0.52) * 2.0;
            if (lum_factor < 0.2) lum_factor = 0.2;

            # Penalize isolated micro-details (< 1.5% pixel share) to avoid spot outliers:
            outlier_mult = (cov < 0.015) ? 0.08 : 1.0;

            score = cov_factor * chroma_factor * lum_factor * outlier_mult;
            if (score > best_score) {
                best_score = score;
                best_idx = i;
            }
        }
    }

    # MONOCHROME GATE: If wallpaper has virtually zero saturation (< 2.5%),
    # it is strictly black and white. Never invent blue/green/yellow accents!
    if (avg_sat < 0.025 || (best_idx >= 0 && s_arr[best_idx] < 0.025)) {
        print "#EAEAEA";
        exit;
    }

    if (best_idx >= 0) {
        final_h = h_arr[best_idx];
        final_s = s_arr[best_idx];
        final_l = l_arr[best_idx];

        # Ensure optimal midtone contrast without distorting authentic saturation
        if (final_l < 0.50) final_l = 0.52;
        if (final_l > 0.68) final_l = 0.60;

        print hsl2rgb(final_h, final_s, final_l);
    } else {
        print "#EAEAEA";
    }
}' 2>/dev/null || echo "#EAEAEA")

[ -z "$ACCENT" ] && ACCENT=$([ "$MODE" = "light" ] && echo "#2D3139" || echo "#EAEAEA")

# 4. Generate high-contrast wallpaper-tinted white typography
DERIVED_COLORS=$(awk -v hex="$ACCENT" '
function hex2rgb(h,   rgb) {
    h = substr(h, 2);
    rgb["r"] = strtonum("0x" substr(h, 1, 2)) / 255.0;
    rgb["g"] = strtonum("0x" substr(h, 3, 2)) / 255.0;
    rgb["b"] = strtonum("0x" substr(h, 5, 2)) / 255.0;
    return rgb["r"] "," rgb["g"] "," rgb["b"];
}
function rgb2hsl(r, g, b,   max, min, d, h, s, l) {
    max = (r > g) ? ((r > b) ? r : b) : ((g > b) ? g : b);
    min = (r < g) ? ((r < b) ? r : b) : ((g < b) ? g : b);
    l = (max + min) / 2.0;
    if (max == min) {
        h = 0; s = 0;
    } else {
        d = max - min;
        sat = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);
        if (max == r) h = (g - b) / d + (g < b ? 6 : 0);
        else if (max == g) h = (b - r) / d + 2;
        else h = (r - g) / d + 4;
        h /= 6.0;
    }
    return h "," s "," l;
}
function hsl2rgb(h, s, l,   q, p, c, t, i) {
    q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
    p = 2.0 * l - q;
    for (i = 1; i <= 3; i++) {
        t = (i == 1) ? h + 1.0/3.0 : ((i == 2) ? h : h - 1.0/3.0);
        if (t < 0) t += 1.0;
        if (t > 1) t -= 1.0;
        if (t < 1.0/6.0) c[i] = p + (q - p) * 6.0 * t;
        else if (t < 1.0/2.0) c[i] = q;
        else if (t < 2.0/3.0) c[i] = p + (q - p) * (2.0/3.0 - t) * 6.0;
        else c[i] = p;
    }
    return sprintf("#%02X%02X%02X", int(c[1]*255 + 0.5), int(c[2]*255 + 0.5), int(c[3]*255 + 0.5));
}
BEGIN {
    split(hex2rgb(hex), rgb, ",");
    split(rgb2hsl(rgb[1], rgb[2], rgb[3]), hsl, ",");
    h = hsl[1];
    # Crisp wallpaper-tinted white (L=96%, subtle 7.5% tint matching wallpaper hue)
    # Subtext0: 82% luminance
    # Subtext1: 70% luminance
    printf "%s %s %s", hsl2rgb(h, 0.075, 0.96), hsl2rgb(h, 0.075, 0.82), hsl2rgb(h, 0.075, 0.70);
}' 2>/dev/null || echo "#F2F1F0 #D2CECC #B3AEA9")

read -r TEXT_COLOR SUBTEXT0 SUBTEXT1 <<< "$DERIVED_COLORS"

# 5. Merge metadata & vibrant accent into colors.json in-place
RAW_COLORS="$TARGET_CACHE/colors.json.raw"
[ ! -f "$RAW_COLORS" ] && RAW_COLORS="$TARGET_CACHE/colors.json"
if [ -f "$RAW_COLORS" ]; then
    jq --argjson il "$IS_LIGHT_VAL" --arg tl "$TOP_LUM_VAL" --arg ac "$ACCENT" --arg tx "$TEXT_COLOR" --arg s0 "$SUBTEXT0" --arg s1 "$SUBTEXT1" \
        '. + {
            isLight: $il,
            topLuminance: ($tl|tonumber),
            mauve: (if $ac != "" then $ac else .mauve end),
            primary: (if $ac != "" then $ac else .primary end),
            accent: (if $ac != "" then $ac else .primary end),
            cursor_bg: (if $ac != "" then $ac else .primary end),
            cursor_border: (if $ac != "" then $ac else .primary end),
            selection_bg: (if $ac != "" then $ac else .primary end),
            active_border_1: (if $ac != "" then $ac else .primary end),
            active_border_2: $s0,
            text: $tx,
            foreground: $tx,
            subtext0: $s0,
            subtext1: $s1,
            overlay0: (if .overlay0 == "#6c7086" or .overlay0 == null then $s1 else .overlay0 end),
            overlay1: (if .overlay1 == "#7f849c" or .overlay1 == null then $s0 else .overlay1 end),
            overlay2: (if .overlay2 == "#9399b2" or .overlay2 == null then $tx else .overlay2 end)
        }' \
        "$RAW_COLORS" > "$TARGET_CACHE/colors.json.tmp" 2>/dev/null && \
    mv -f "$TARGET_CACHE/colors.json.tmp" "$TARGET_CACHE/colors.json"
    rm -f "$TARGET_CACHE/colors.json.raw" 2>/dev/null || true
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


    if [ -d "$HOME/.config/cava/themes" ]; then
        r=$((16#${ACCENT:1:2}))
        g=$((16#${ACCENT:3:2}))
        b=$((16#${ACCENT:5:2}))
        awk -v r="$r" -v g="$g" -v b="$b" '
BEGIN {
    print "[color]\ngradient = 1\ngradient_count = 8"
    for (i = 0; i < 8; i++) {
        t = 0.28 + (0.72 * (i / 7.0))
        printf "gradient_color_%d = \"#%02x%02x%02x\"\n", i+1, int(r * t), int(g * t), int(b * t)
    }
}' > "$HOME/.config/cava/themes/wallust" 2>/dev/null || true
    fi

    HEX_ACCENT="${ACCENT#'#'}"
    for f in "$HOME/.config/fuzzel/fuzzel.ini" "$HOME/nix/dotfiles/fuzzel/fuzzel.ini"; do
        if [ -f "$f" ]; then
            sed -i -E "s/^(match = ).*/\1${HEX_ACCENT}ff/; s/^(selection-match = ).*/\1${HEX_ACCENT}ff/; s/^(background = ).*/\112131833/" "$f" 2>/dev/null || true
        fi
    done
fi

# Notify client applications if running
pkill -USR2 cava 2>/dev/null || true
pkill -USR1 -u "${USER:-$LOGNAME}" -x foot 2>/dev/null || true
pkill -USR1 -u "${USER:-$LOGNAME}" -f "foot --server" 2>/dev/null || true
alacritty msg config -r >/dev/null 2>&1 || true
RESTORE_SCRIPT="$HOME/.config/hypr/scripts/quickshell/restore_state.sh"
[ ! -x "$RESTORE_SCRIPT" ] && RESTORE_SCRIPT="$HOME/nix/dotfiles/hypr/scripts/quickshell/restore_state.sh"
if [ -x "$RESTORE_SCRIPT" ]; then "$RESTORE_SCRIPT" >/dev/null 2>&1 || true; fi
if command -v quickshell >/dev/null 2>&1; then
    quickshell ipc -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" call main reloadTheme >/dev/null 2>&1 || true
fi
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita" >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita:dark" >/dev/null 2>&1 || true
    if [ -n "${ACCENT:-}" ] && [ "${#ACCENT}" -ge 7 ]; then
        r=$((16#${ACCENT:1:2}))
        g=$((16#${ACCENT:3:2}))
        b=$((16#${ACCENT:5:2}))
        GNOME_ACCENT=$(awk -v r="$r" -v g="$g" -v b="$b" '
BEGIN {
    rf = r / 255.0; gf = g / 255.0; bf = b / 255.0;
    max = (rf > gf ? (rf > bf ? rf : bf) : (gf > bf ? gf : bf));
    min = (rf < gf ? (rf < bf ? rf : bf) : (gf < bf ? gf : bf));
    delta = max - min;
    if (delta == 0) { h = 0; s = 0; }
    else {
        s = delta / max;
        if (rf == max) { h = (gf - bf) / delta; if (h < 0) h += 6; }
        else if (gf == max) { h = 2 + (bf - rf) / delta; }
        else { h = 4 + (rf - gf) / delta; }
        h = h / 6.0;
    }
    if (s < 0.15) print "slate";
    else if (h < 0.05 || h >= 0.95) print "red";
    else if (h < 0.12) print "orange";
    else if (h < 0.20) print "yellow";
    else if (h < 0.45) print "green";
    else if (h < 0.55) print "teal";
    else if (h < 0.70) print "blue";
    else if (h < 0.82) print "purple";
    else print "pink";
}' 2>/dev/null || echo "purple")
        gsettings set org.gnome.desktop.interface accent-color "$GNOME_ACCENT" >/dev/null 2>&1 || true
    fi
fi
