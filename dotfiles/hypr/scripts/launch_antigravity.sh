#!/usr/bin/env bash
# launch_antigravity.sh
# Spawns a new Antigravity window reliably.
# If Antigravity is already running, sends Ctrl+Shift+N to spawn a new window on the running hub;
# otherwise starts the main antigravity process.

set -euo pipefail

hyprctl() { timeout 3 env hyprctl "$@"; }

if hyprctl clients | grep -q "class: antigravity"; then
    # Focus existing antigravity window and trigger internal New Window (Ctrl+Shift+N)
    hyprctl dispatch focuswindow "class:^antigravity$" >/dev/null 2>&1 || true
    sleep 0.05
    ydotool key 29:1 42:1 49:1 49:0 42:0 29:0 2>/dev/null || true
else
    exec antigravity "$@"
fi
