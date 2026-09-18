#!/usr/bin/env bash
set -uo pipefail

systemctl --user stop graphical-session.target graphical-session-pre.target 2>/dev/null || true

# Try graceful Hyprland IPC exit dispatcher
if ! hyprctl dispatch exit 2>/dev/null; then
    sleep 0.2
    # Fallback to terminating NixOS Hyprland wrapper process
    pkill -u "$(id -u)" -f '([H]yprland|\.Hyprland-wrapp)' 2>/dev/null || true
fi