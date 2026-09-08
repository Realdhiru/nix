#!/usr/bin/env bash
# toggle_dark_mode.sh -- Manual toggle between Normal and Dark Mode UI (opacity & contrast)
# Bound to: CTRL + SUPER + D
set -euo pipefail

STATE_FILE="$HOME/.cache/matugen/wallpaper_is_light.txt"
QS_COLORS="$HOME/.cache/matugen/qs_colors.json"

mkdir -p "$HOME/.cache/matugen"

current="false"
if [ -f "$STATE_FILE" ]; then
    current=$(cat "$STATE_FILE" 2>/dev/null || echo "false")
fi

if [ "$current" = "true" ]; then
    next="false"
    mode_name="Normal (Transparent)"
    icon="weather-clear-night"
else
    next="true"
    mode_name="Dark Contrast (Frosted)"
    icon="weather-clear"
fi

echo "$next" > "$STATE_FILE"

# Update isLight in qs_colors.json to trigger Quickshell live update
if [ -f "$QS_COLORS" ]; then
    if [ "$next" = "true" ]; then
        jq '.isLight = true' "$QS_COLORS" > "$QS_COLORS.tmp" 2>/dev/null && mv "$QS_COLORS.tmp" "$QS_COLORS"
    else
        jq '.isLight = false' "$QS_COLORS" > "$QS_COLORS.tmp" 2>/dev/null && mv "$QS_COLORS.tmp" "$QS_COLORS"
    fi
fi

# Send brief OSD notification
notify-send -a "Theme" -u low -i "$icon" -r 9988 "UI Mode" "$mode_name"
