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
    # Re-apply persistent compositor flags from modes.json (single source of truth)
    MODES_CTL="$HOME/nix/dotfiles/hypr/scripts/mode_ctl.sh"
    [ ! -x "$MODES_CTL" ] && MODES_CTL="$HOME/.config/hypr/scripts/mode_ctl.sh"
    [ -x "$MODES_CTL" ] && bash "$MODES_CTL" apply > /dev/null 2>&1 || true
fi

# 3. Clean quickshell spawn
QS_TARGET="$HOME/.config/hypr/scripts/quickshell/Shell.qml"
QS_MANAGER="$HOME/nix/dotfiles/hypr/scripts/qs_manager.sh"
[ ! -x "$QS_MANAGER" ] && QS_MANAGER="$HOME/.config/hypr/scripts/qs_manager.sh"

sleep 0.2
bash "$QS_MANAGER" reload >/dev/null 2>&1 || true