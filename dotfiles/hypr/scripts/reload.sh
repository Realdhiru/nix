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

# 2. Quickshell lifecycle management
# Avoid killing and restarting Quickshell on standard config reload to prevent
# screen blinking and wasted CPU/battery power. Only cold boot if not running
# or if explicitly requested via --quickshell.
FORCE_QS=false
for arg in "$@"; do
    if [ "$arg" = "--quickshell" ] || [ "$arg" = "-q" ] || [ "$arg" = "--force" ]; then
        FORCE_QS=true
        break
    fi
done

QS_RUNNING=false
if pgrep -f "Shell.qml" >/dev/null || pgrep -x qs >/dev/null || pgrep -x quickshell >/dev/null; then
    QS_RUNNING=true
fi

if [ "$FORCE_QS" = true ]; then
    pkill -f "Shell.qml" 2>/dev/null || true
    pkill -x qs 2>/dev/null || true
    pkill -x quickshell 2>/dev/null || true
    sleep 0.2
    QS_RUNNING=false
fi

if [ "$QS_RUNNING" = false ]; then
    QS_TARGET="$HOME/.config/hypr/scripts/quickshell/Shell.qml"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl dispatch exec "quickshell -p $QS_TARGET" >/dev/null 2>&1
    else
        nohup quickshell -p "$QS_TARGET" >/dev/null 2>&1 &
        disown
    fi
fi