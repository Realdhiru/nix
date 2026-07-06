#!/usr/bin/env bash

# Strict execution environment: Catch undefined variables and pipe failures
set -uo pipefail

# 1. Reload Hyprland (Applies window rules, keybinds, monitor configs)
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1
fi

# 2. Determine the correct Quickshell binary dynamically from the Nix store path
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

# 3. Smart Quickshell Reloading
# Check if the Quickshell daemon is currently running
if pgrep -x "quickshell" >/dev/null || pgrep -x "qs" >/dev/null; then
    # Daemon is alive: Use the fast IPC hot-reload hook
    "$QS_BIN" -p "$QS_TARGET" ipc call main forceReload >/dev/null 2>&1 &
else
    # Daemon is dead/crashed: Cold boot a fresh instance in the background
    "$QS_BIN" -p "$QS_TARGET" >/dev/null 2>&1 &
fi