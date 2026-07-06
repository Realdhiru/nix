#!/usr/bin/env bash

# Strict execution environment: Catch undefined variables and pipe failures
set -uo pipefail

# 1. Reload Hyprland first (Applies window rules, keybinds, monitor configs instantly)
# Note: If hyprland.conf contains 'exec = qs...', this may auto-spawn an instance.
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1
fi

# 2. Hard-kill all Quickshell processes. 
# Using -f catches NixOS wrapped binaries that bypass strict name checks.
# This wipes the original instance AND any instance just spawned by hyprctl reload.
pkill -f "Shell.qml" 2>/dev/null || true
pkill -x qs 2>/dev/null || true
pkill -x quickshell 2>/dev/null || true

# 3. Give Wayland a fraction of a second to unmap the old surfaces
sleep 0.3

# 4. Resolve the correct NixOS binary dynamically
QS_BIN=""
if command -v quickshell >/dev/null 2>&1; then
    QS_BIN="quickshell"
elif command -v qs >/dev/null 2>&1; then
    QS_BIN="qs"
else
    # Failsafe abort if the binary isn't in PATH
    exit 1
fi

QS_TARGET="$HOME/.config/hypr/scripts/quickshell/Shell.qml"

# 5. Cold boot exactly ONE fresh instance in the background
"$QS_BIN" -p "$QS_TARGET" >/dev/null 2>&1 &