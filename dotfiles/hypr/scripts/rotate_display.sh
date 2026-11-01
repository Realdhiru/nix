#!/usr/bin/env bash
#
# rotate_display.sh -- toggle 180° rotation (transform 0 <-> 2) on the
# focused monitor without touching mode, resolution, or refresh rate.
#

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/monitors"
mkdir -p "$STATE_DIR"
TRANSFORM_FILE="$STATE_DIR/transform.txt"

MONITOR=""
if command -v hyprctl >/dev/null 2>&1; then
    MONITOR=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty' 2>/dev/null || true)
    [ -n "$MONITOR" ] || MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name // empty' 2>/dev/null || true)
fi
[ -n "$MONITOR" ] || exit 1

# Current transform from hyprctl
CUR=$(hyprctl monitors -j 2>/dev/null | jq -r --arg m "$MONITOR" '.[] | select(.name == $m) | .transform // 0' 2>/dev/null || true)
CUR="${CUR:-0}"

TARGET_ARG="${1:-toggle}"
if [ "$TARGET_ARG" = "0" ] || [ "$TARGET_ARG" = "normal" ]; then
    NEW=0
elif [ "$TARGET_ARG" = "2" ] || [ "$TARGET_ARG" = "180" ] || [ "$TARGET_ARG" = "inverted" ]; then
    NEW=2
elif [ "$CUR" = "2" ]; then
    NEW=0
else
    NEW=2
fi

# Persist transform state in user state dir (never git-tracked files)
echo "$NEW" > "$TRANSFORM_FILE"

# Also update cache file for backwards compatibility with SysData
CACHE_FILE="$HOME/.cache/hypr_power_monitor.conf"
if [ -f "$CACHE_FILE" ]; then
    if grep -q "transform," "$CACHE_FILE" 2>/dev/null; then
        sed -i -E "s/transform,[0-9]+/transform,$NEW/g" "$CACHE_FILE"
    else
        sed -i "s/$/transform,$NEW/" "$CACHE_FILE"
    fi
fi

# Apply transform cleanly in Hyprland Lua engine WITHOUT touching mode or rate
DESC=$(hyprctl monitors -j 2>/dev/null | jq -r --arg m "$MONITOR" '.[] | select(.name == $m) | .description // empty' 2>/dev/null || true)
if [ -n "$DESC" ]; then
    hyprctl eval "hl.monitor({ output = 'desc:$DESC', transform = $NEW }); hl.exec_scheduled_prop_refresh_immediately()" >/dev/null 2>&1
fi
hyprctl eval "hl.monitor({ output = '$MONITOR', transform = $NEW }); hl.exec_scheduled_prop_refresh_immediately()" >/dev/null 2>&1

if [ "$NEW" = "2" ]; then
    notify-send -a "Display" -u low -i video-display "Inverted 180°" 2>/dev/null || true
else
    notify-send -a "Display" -u low -i video-display "Standard" 2>/dev/null || true
fi

exit 0
