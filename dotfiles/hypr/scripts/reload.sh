#!/usr/bin/env bash

# Strict execution environment: Catch undefined variables and pipe failures
set -uo pipefail

# 1. Reload Hyprland first (Applies window rules, keybinds, monitor configs instantly)
# Note: If hyprland.conf contains 'exec = qs...', this may auto-spawn an instance.
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1
    # Re-apply persistent visual overrides if wallpaper is killed, gaming mode active, or in power-saver
    PROFILE="$(cat "$HOME/.cache/qs_power_profile" 2>/dev/null || cat /tmp/qs_power_profile 2>/dev/null || echo "")"
    if [ -f "$HOME/.cache/wallpaper_killed" ] || [ -f "$HOME/.cache/gaming_mode" ] || [ "$PROFILE" = "power-saver" ]; then
        hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0 } })" >/dev/null 2>&1 || true
        hyprctl eval "hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })" >/dev/null 2>&1 || true
        if [ -f "$HOME/.cache/wallpaper_killed" ] || [ "$PROFILE" = "power-saver" ]; then
            hyprctl eval "hl.config({ animations = { enabled = false } })" >/dev/null 2>&1 || true
        fi
    fi
    if [ -f "$HOME/.cache/gaming_mode" ]; then
        hyprctl eval "hl.config({ render = { direct_scanout = 2 }, misc = { vrr = 1 }, general = { allow_tearing = true } })" >/dev/null 2>&1 || true
    fi
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
nohup "$QS_BIN" -p "$QS_TARGET" >/dev/null 2>&1 &
disown