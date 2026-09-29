#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_CTL="${SCRIPT_DIR}/state_ctl.sh"

if [ ! -f "$STATE_CTL" ]; then
    STATE_CTL="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
fi

CURRENT=$("$STATE_CTL" get ui.themeMode)

if [ "$CURRENT" = "light" ]; then
    "$STATE_CTL" set ui.themeMode "dark"
    echo "Switched QuickShell theme to dark"
else
    "$STATE_CTL" set ui.themeMode "light"
    echo "Switched QuickShell theme to light"
fi
