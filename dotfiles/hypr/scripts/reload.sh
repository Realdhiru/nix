#!/usr/bin/env bash

# Strict execution environment: Catch undefined variables and pipe failures
set -uo pipefail

# 1. Quickshell complete process kill (prevents in-place displacement / geometry glitches)
pkill -9 -f "quickshell" 2>/dev/null || true
pkill -9 -f "\.quickshell-wra" 2>/dev/null || true

# Reap orphaned follower processes (playerctl, cava, udevadm)
for pid in $(pgrep -f "playerctl -a --follow" 2>/dev/null || true) $(pgrep -f "cava -p .*cava_topbar.conf" 2>/dev/null || true) $(pgrep -f "udevadm monitor --subsystem-match" 2>/dev/null || true); do
    [ -n "$pid" ] || continue
    ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true)
    if [ "$ppid" = "1" ]; then
        kill -9 "$pid" 2>/dev/null || true
    fi
done

# 2. Hyprland configuration & system-wide reload
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1
    # Re-apply persistent compositor flags
    DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
    PROFILE="$(cat "$DESKTOP_STATE_DIR/power/profile" 2>/dev/null || echo "")"
    if [ -f "$DESKTOP_STATE_DIR/modes/wallpaper_killed" ] || [ -f "$DESKTOP_STATE_DIR/modes/gaming_mode" ] || [ "$PROFILE" = "power-saver" ]; then
        hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } } })" >/dev/null 2>&1 || true
        if [ "$PROFILE" = "power-saver" ] || [ -f "$DESKTOP_STATE_DIR/modes/gaming_mode" ]; then
            hyprctl eval "hl.config({ animations = { enabled = false } })" >/dev/null 2>&1 || true
        fi
    fi
    if [ -f "$DESKTOP_STATE_DIR/modes/gaming_mode" ]; then
        hyprctl eval "hl.config({ render = { direct_scanout = 2 }, misc = { vrr = 1 }, general = { allow_tearing = true } })" >/dev/null 2>&1 || true
    elif [ "$PROFILE" = "power-saver" ]; then
        hyprctl eval "hl.config({ render = { direct_scanout = 2 }, misc = { vrr = 1 }, general = { allow_tearing = false } })" >/dev/null 2>&1 || true
    fi
fi

# 3. Clean quickshell spawn
QS_TARGET="$HOME/.config/hypr/scripts/quickshell/Shell.qml"
QS_MANAGER="$HOME/nix/dotfiles/hypr/scripts/qs_manager.sh"
[ ! -x "$QS_MANAGER" ] && QS_MANAGER="$HOME/.config/hypr/scripts/qs_manager.sh"

sleep 0.2
bash "$QS_MANAGER" reload >/dev/null 2>&1 || true