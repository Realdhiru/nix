#!/usr/bin/env bash
# Fast atomic layout toggle between dwindle (tiling) and scrolling (Niri ribbon)
set -euo pipefail

cur=$(hyprctl getoption general:layout -j 2>/dev/null | jq -r '.str // "dwindle"')
if [ "$cur" = "scrolling" ]; then
    hyprctl eval 'hl.config({ general = { layout = "dwindle" } })' >/dev/null 2>&1
    notify-send -a "Hyprland" "Layout: Dwindle"
else
    hyprctl eval 'hl.config({ general = { layout = "scrolling" } })' >/dev/null 2>&1
    notify-send -a "Hyprland" "Layout: Scrolling"
fi
