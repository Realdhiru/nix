#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE_CTL="$SCRIPT_DIR/mode_ctl.sh"
[ -f "$MODE_CTL" ] || MODE_CTL="$HOME/.config/hypr/scripts/mode_ctl.sh"

DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
MODES_JSON="$DESKTOP_STATE_DIR/modes/modes.json"

CUR_STATE="false"
if [ -s "$MODES_JSON" ]; then
    CUR_STATE=$(jq -r '.active.gaming // false' "$MODES_JSON" 2>/dev/null || echo "false")
fi

if [ "$CUR_STATE" = "true" ]; then
    TARGET="false"
    notify-send -a "Game Mode" -u low "OFF"
else
    TARGET="true"
    notify-send -a "Game Mode" -u normal "ON"
fi

bash "$MODE_CTL" set gaming "$TARGET"
