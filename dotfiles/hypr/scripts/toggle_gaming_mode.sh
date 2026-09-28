#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.cache/gaming_mode"
STATE_CTL="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
NOTIF_TITLE="Efficiency / Gaming Mode"

IS_GAMING="false"
if [ -f "$STATE_CTL" ]; then
    IS_GAMING="$(bash "$STATE_CTL" get modes.gaming 2>/dev/null || echo "false")"
fi

if [ -f "$STATE_FILE" ] || [ "$IS_GAMING" = "true" ]; then
    # Disable Gaming Mode
    rm -f "$STATE_FILE"
    [ -f "$STATE_CTL" ] && bash "$STATE_CTL" set modes.gaming false 2>/dev/null || true

    # Reset compositor gaming flags to defaults
    hyprctl eval "hl.config({ render = { direct_scanout = 0 }, misc = { vrr = 0 }, general = { allow_tearing = false } })" >/dev/null 2>&1 || true

    # Only restore blur, shadow, and window opacity if not in power-saver and wallpaper not killed
    CURRENT_PROFILE="$(cat "$HOME/.cache/qs_power_profile" 2>/dev/null || cat /tmp/qs_power_profile 2>/dev/null || echo "balanced")"
    if [ "$CURRENT_PROFILE" != "power-saver" ] && [ ! -f "$HOME/.cache/wallpaper_killed" ]; then
        hyprctl eval "hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true }, active_opacity = 1.0, inactive_opacity = 1.0 } })" >/dev/null 2>&1 || true
        hyprctl reload >/dev/null 2>&1 || true
    fi

    notify-send -a "Game Mode" -u low "OFF"
else
    # Enable Gaming Mode
    touch "$STATE_FILE"
    [ -f "$STATE_CTL" ] && bash "$STATE_CTL" set modes.gaming true 2>/dev/null || true

    # 1. 100% opaque windows across all applications (eliminates GPU alpha-blending and triggers occlusion culling)
    hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0 } })" >/dev/null 2>&1 || true
    hyprctl eval "hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })" >/dev/null 2>&1 || true

    # 2. Animations stay ENABLED (user rule: "not animations")
    # 3. Wallpapers stay ENABLED (user rule: "not wallpapers")

    # 4. Zero-latency compositor flags: Direct Scanout (bypasses composition latency), VRR (adaptive sync), tearing
    hyprctl eval "hl.config({ render = { direct_scanout = 2 }, misc = { vrr = 1 }, general = { allow_tearing = true } })" >/dev/null 2>&1 || true

    notify-send -a "Game Mode" -u normal "ON"
fi
