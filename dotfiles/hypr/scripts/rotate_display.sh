#!/usr/bin/env bash
#
# rotate_display.sh -- toggle 180° rotation (transform 0 <-> 2) on the
# focused monitor and persist it in ~/.cache/hypr_power_monitor.conf
# (sourced by hyprland.conf, so it survives reboots).
#
# Cache convention matches Config.qml/MonitorPopup.qml:
#   monitor=<name>,<res>@<rate>,<pos>,<scale>,bitdepth,10[,transform,N]
# (transform omitted when 0). The APPLY string always includes an explicit
# transform so "restore to 0" actually resets the running display.

set -uo pipefail

CACHE_FILE="$HOME/.cache/hypr_power_monitor.conf"
MONITOR=""

# Focused monitor, fall back to the first one
if command -v hyprctl >/dev/null 2>&1; then
    MONITOR=$(hyprctl activeworkspace -j 2>/dev/null \
        | python3 -c "import json,sys; print(json.load(sys.stdin).get('monitor',''))" 2>/dev/null)
    [ -n "$MONITOR" ] || MONITOR=$(hyprctl monitors -j 2>/dev/null \
        | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
fi

[ -n "$MONITOR" ] || exit 1

CUR=$(hyprctl monitors -j 2>/dev/null | python3 -c "
import json, sys
monitors = json.load(sys.stdin)
for m in monitors:
    if m['name'] == '$MONITOR':
        print(m['transform']); break
")
CUR="${CUR:-0}"

if [ "$CUR" = "2" ]; then NEW=0; else NEW=2; fi

# Base monitor spec (everything before any ,transform,N segment)
if grep -q "^monitor=$MONITOR," "$CACHE_FILE" 2>/dev/null; then
    BASE="$(grep "^monitor=$MONITOR," "$CACHE_FILE" | head -n 1 | sed -E 's/,transform,[0-9]*//' | cut -d= -f2-)"
else
    BASE="$MONITOR"
    echo "monitor=$MONITOR" >> "$CACHE_FILE"
fi

# Update the cache: strip any old transform, append the new one unless 0
sed -i "/^monitor=$MONITOR,/ s/,transform,[0-9]*//" "$CACHE_FILE"
if [ "$NEW" != "0" ]; then
    sed -i "/^monitor=$MONITOR,/ s|\$|,transform,$NEW|" "$CACHE_FILE"
fi

# Apply live (explicit transform so restoring to 0 works)
hyprctl keyword monitor "$BASE,transform,$NEW" >/dev/null 2>&1

# Re-commit the wallpaper layer surface to the rotated output. A 180° toggle
# keeps logical dimensions, so a full daemon restart (ensure_awww.sh
# --restart) is unnecessary and only causes a visible reload flash. A plain
# re-push (~0.2 s, warm cache) re-commits the surface instead. Videos run on
# their own mpvpaper surface and need nothing.
WALL="$(cat "$HOME/.cache/current_wallpaper.txt" 2>/dev/null)"
if [ -n "$WALL" ] && [ -f "$WALL" ]; then
    EXT="${WALL##*.}"
    EXT="${EXT,,}"
    case "$EXT" in
        mp4|mkv|mov|webm) : ;;
        *)
            if awww query >/dev/null 2>&1; then
                awww img "$WALL" \
                    --transition-type fade \
                    --transition-step 255 \
                    --transition-duration 0.1 \
                    --transition-fps 60 >/dev/null 2>&1
            else
                "$HOME/.config/hypr/scripts/ensure_awww.sh" >/dev/null 2>&1
                awww img "$WALL" \
                    --transition-type fade \
                    --transition-step 255 \
                    --transition-duration 0.1 \
                    --transition-fps 60 >/dev/null 2>&1
            fi
            ;;
    esac
fi

exit 0
