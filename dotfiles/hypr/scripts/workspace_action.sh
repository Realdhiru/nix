#!/usr/bin/env bash
# Fast dispatcher for external monitor workspaces (workspaces 11-20)
# Only active when an external display is connected and monitor mode is "extend".
set -euo pipefail

ACTION="${1:-switch}"
KEY="${2:-1}"

if [ "$KEY" -eq 0 ] 2>/dev/null; then
    INDEX=10
else
    INDEX="$KEY"
fi

TARGET_WS=$((10 + INDEX))

DESKTOP_STATE="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
INTENT_FILE="$DESKTOP_STATE/monitors/intent.json"

# Check layout intent: must be "extend"
LAYOUT="extend"
if [ -f "$INTENT_FILE" ]; then
    LAYOUT=$(grep -o '"layout"[[:space:]]*:[[:space:]]*"[^"]*"' "$INTENT_FILE" | head -n 1 | cut -d'"' -f4 || echo "extend")
fi

if [ "$LAYOUT" != "extend" ]; then
    exit 0
fi

# Detect active external monitor
EXT_MON=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select((.name | test("^(eDP|LVDS|DSI)") | not) and .disabled == false) | .name' | head -n 1 || true)

if [ -z "$EXT_MON" ]; then
    exit 0
fi

if [ "$ACTION" = "switch" ]; then
    hyprctl eval "hl.dsp.focus({ monitor = '$EXT_MON' }); hl.dsp.focus({ workspace = $TARGET_WS })" >/dev/null 2>&1
elif [ "$ACTION" = "move" ]; then
    hyprctl eval "hl.dsp.window.move({ workspace = $TARGET_WS })" >/dev/null 2>&1
fi
