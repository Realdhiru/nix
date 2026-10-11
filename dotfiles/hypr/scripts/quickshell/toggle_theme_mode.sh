#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_CTL="${SCRIPT_DIR}/state_ctl.sh"
TERMINAL_OPACITY="${SCRIPT_DIR}/../../../wallust/terminal-opacity.sh"

if [ ! -f "$STATE_CTL" ]; then
    STATE_CTL="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
fi
if [ ! -f "$TERMINAL_OPACITY" ]; then
    TERMINAL_OPACITY="$HOME/nix/dotfiles/wallust/terminal-opacity.sh"
fi

CURRENT=$("$STATE_CTL" get ui.themeMode)

if [ "$CURRENT" = "light" ]; then
    "$STATE_CTL" set ui.themeMode "dark"
    MESSAGE="QuickShell visibility boost OFF"
else
    "$STATE_CTL" set ui.themeMode "light"
    MESSAGE="QuickShell visibility boost ON"
fi

source "$TERMINAL_OPACITY"
apply_terminal_opacity --reload
echo "$MESSAGE"
