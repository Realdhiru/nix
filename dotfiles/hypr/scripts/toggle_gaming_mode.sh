#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.cache/gaming_mode"
NOTIF_TITLE="Efficiency / Gaming Mode"

if [ -f "$STATE_FILE" ]; then
    # Disable Gaming Mode
    rm -f "$STATE_FILE"

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

    # 1. 100% opaque windows across all applications (eliminates GPU alpha-blending and triggers occlusion culling)
    hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0 } })" >/dev/null 2>&1 || true
    hyprctl eval "hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })" >/dev/null 2>&1 || true

    # 2. Animations stay ENABLED (user rule: "not animations")
    # 3. Wallpapers stay ENABLED (user rule: "not wallpapers")

    # 4. Zero-latency compositor flags: Direct Scanout (bypasses composition latency), VRR (adaptive sync), tearing
    hyprctl eval "hl.config({ render = { direct_scanout = 2 }, misc = { vrr = 1 }, general = { allow_tearing = true } })" >/dev/null 2>&1 || true

    notify-send -a "Game Mode" -u normal "ON"
fi
