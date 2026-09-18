#!/usr/bin/env bash

# Strict execution environment: Catch undefined variables and pipe failures
set -uo pipefail

# 1. Reload Hyprland first (Applies window rules, keybinds, monitor configs instantly)
# Note: If hyprland.conf contains 'exec = qs...', this may auto-spawn an instance.
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1
    # Re-apply persistent compositor flags
    PROFILE="$(cat "$HOME/.cache/qs_power_profile" 2>/dev/null || cat /tmp/qs_power_profile 2>/dev/null || echo "")"
    if [ -f "$HOME/.cache/wallpaper_killed" ] || [ -f "$HOME/.cache/gaming_mode" ] || [ "$PROFILE" = "power-saver" ]; then
        hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } } })" >/dev/null 2>&1 || true
        if [ -f "$HOME/.cache/wallpaper_killed" ] || [ "$PROFILE" = "power-saver" ]; then
            hyprctl eval "hl.config({ animations = { enabled = false } })" >/dev/null 2>&1 || true
        fi
    fi
    if [ -f "$HOME/.cache/gaming_mode" ]; then
        hyprctl eval "hl.config({ render = { direct_scanout = 2 }, misc = { vrr = 1 }, general = { allow_tearing = true } })" >/dev/null 2>&1 || true
    fi
fi

# 2. Quickshell lifecycle management
QS_TARGET="$HOME/.config/hypr/scripts/quickshell/Shell.qml"

if pgrep -f "Shell.qml" >/dev/null || pgrep -x qs >/dev/null || pgrep -x quickshell >/dev/null; then
    # Trigger instantaneous hot reload via native IPC handler
    if ! quickshell -p "$QS_TARGET" ipc call topbar queueReload >/dev/null 2>&1; then
        # Fallback if IPC didn't respond (e.g. process hung): restart cleanly
        pkill -9 quickshell 2>/dev/null || true
        pkill -9 -f "\.quickshell-wra" 2>/dev/null || true
        sleep 0.1
        hyprctl eval "hl.dispatch(hl.dsp.exec_cmd('quickshell -p $QS_TARGET'))" >/dev/null 2>&1 || (nohup quickshell -p "$QS_TARGET" >/dev/null 2>&1 & disown)
    fi
else
    # Not running: spawn cleanly
    hyprctl eval "hl.dispatch(hl.dsp.exec_cmd('quickshell -p $QS_TARGET'))" >/dev/null 2>&1 || (nohup quickshell -p "$QS_TARGET" >/dev/null 2>&1 & disown)
fi