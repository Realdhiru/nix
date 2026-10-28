#!/usr/bin/env bash
set -euo pipefail

DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
STATE_FILE="$DESKTOP_STATE_DIR/modes/gaming_mode"
STATE_CTL="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
NOTIF_TITLE="Efficiency / Gaming Mode"

mkdir -p "$DESKTOP_STATE_DIR/modes"

IS_GAMING="false"
if [ -f "$STATE_CTL" ]; then
    IS_GAMING="$(bash "$STATE_CTL" get modes.gaming 2>/dev/null || echo "false")"
fi

if [ -f "$STATE_FILE" ] || [ "$IS_GAMING" = "true" ]; then
    # Disable Gaming Mode
    rm -f "$STATE_FILE" "$HOME/.cache/gaming_mode"
    [ -f "$STATE_CTL" ] && bash "$STATE_CTL" set modes.gaming false 2>/dev/null || true

    # Reset compositor gaming flags to defaults
    hyprctl eval "hl.config({ render = { direct_scanout = 0 }, misc = { vrr = 0 }, general = { allow_tearing = false } })" >/dev/null 2>&1 || true

    CURRENT_PROFILE="$(cat "$DESKTOP_STATE_DIR/power/profile" 2>/dev/null || echo "balanced")"
    if [ "$CURRENT_PROFILE" = "power-saver" ]; then
        # Maintain power-saver visual flags
        hyprctl eval "hl.config({ render = { direct_scanout = 2 }, misc = { vrr = 1 }, general = { allow_tearing = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false } }, animations = { enabled = false } })" >/dev/null 2>&1 || true
        hyprctl eval "hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })" >/dev/null 2>&1 || true
    elif [ -f "$DESKTOP_STATE_DIR/modes/wallpaper_killed" ]; then
        # Maintain wallpaper-killed visual flags (solid opacity, no blur/shadow, but animations ON)
        hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } }, animations = { enabled = true } })" >/dev/null 2>&1 || true
        hyprctl eval "hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })" >/dev/null 2>&1 || true
    else
        # Full normal desktop: restore blur, shadow, animations, and reload window rules
        hyprctl eval "hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true }, active_opacity = 1.0, inactive_opacity = 1.0 }, animations = { enabled = true } })" >/dev/null 2>&1 || true
        hyprctl reload >/dev/null 2>&1 || true
    fi
    bash "$HOME/nix/dotfiles/wallust/terminal-opacity.sh" --reload 2>/dev/null || true

    notify-send -a "Game Mode" -u low "OFF"
else
    # Enable Gaming Mode
    touch "$STATE_FILE"
    [ -f "$STATE_CTL" ] && bash "$STATE_CTL" set modes.gaming true 2>/dev/null || true

    # 1. 100% opaque windows across all applications (eliminates GPU alpha-blending and triggers occlusion culling)
    # 2. Disable animations for instant frame response
    hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0 }, animations = { enabled = false } })" >/dev/null 2>&1 || true
    hyprctl eval "hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })" >/dev/null 2>&1 || true
    bash "$HOME/nix/dotfiles/wallust/terminal-opacity.sh" --reload 2>/dev/null || true

    # 3. Wallpapers stay ENABLED
    # 4. Zero-latency compositor flags: Direct Scanout (bypasses composition latency), VRR (adaptive sync), tearing
    hyprctl eval "hl.config({ render = { direct_scanout = 2 }, misc = { vrr = 1 }, general = { allow_tearing = true } })" >/dev/null 2>&1 || true

    notify-send -a "Game Mode" -u normal "ON"
fi
