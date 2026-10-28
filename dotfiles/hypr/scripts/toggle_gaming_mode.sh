#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE_CTL="$SCRIPT_DIR/mode_ctl.sh"
[ -f "$MODE_CTL" ] || MODE_CTL="$HOME/.config/hypr/scripts/mode_ctl.sh"

NEW_STATE="$(bash "$MODE_CTL" toggle gaming)"

if [ "$NEW_STATE" = "true" ]; then
    notify-send -a "Game Mode" -u normal "ON"
else
    notify-send -a "Game Mode" -u low "OFF"
fi
