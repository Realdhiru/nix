#!/usr/bin/env bash
# Fast atomic layout toggle between dwindle (tiling) and scrolling (Niri ribbon)
set -euo pipefail

STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}/layout"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/current_layout.txt"

cur=$(hyprctl getoption general:layout -j 2>/dev/null | jq -r '.str // "dwindle"')
if [ "$cur" = "scrolling" ]; then
    next="dwindle"
else
    next="scrolling"
fi

hyprctl eval "hl.config({ general = { layout = \"$next\" } })" >/dev/null 2>&1
echo "$next" > "$STATE_FILE.tmp" && mv -f "$STATE_FILE.tmp" "$STATE_FILE"

if [ "$next" = "scrolling" ]; then
    notify-send -a "Hyprland" "Layout: Scrolling"
else
    notify-send -a "Hyprland" "Layout: Dwindle"
fi
