#!/usr/bin/env bash
# Keep terminal background translucency in sync with the QuickShell visibility mode.

apply_terminal_opacity() {
    local opacity="0.30"
    local state_file="$HOME/.cache/quickshell/state.json"
    local alacritty_colors="$HOME/.cache/theme/alacritty-colors.toml"
    local power_profile="$(cat "$HOME/.cache/qs_power_profile" 2>/dev/null || cat /tmp/qs_power_profile 2>/dev/null || echo "")"

    # Check for Solid Mode triggers: wallpaper killed, gaming mode, or power-saver profile
    if [ -f "$HOME/.cache/wallpaper_killed" ] || [ -f "$HOME/.cache/gaming_mode" ] || [ "$power_profile" = "power-saver" ]; then
        opacity="1.0"
    elif [ -f "$state_file" ] && [ "$(jq -r '.modes.wallpaperKilled // false' "$state_file" 2>/dev/null || true)" = "true" ]; then
        opacity="1.0"
    elif [ -f "$state_file" ] && [ "$(jq -r '.modes.gaming // false' "$state_file" 2>/dev/null || true)" = "true" ]; then
        opacity="1.0"
    elif [ -f "$state_file" ] && [ "$(jq -r '.ui.themeMode // "dark"' "$state_file" 2>/dev/null || true)" = "light" ]; then
        opacity="0.60"
    fi

    if [ -f "$alacritty_colors" ]; then
        sed -i -E "s/^opacity = [0-9.]+$/opacity = ${opacity}/" "$alacritty_colors"
    fi

    if [ "${1:-}" = "--reload" ]; then
        alacritty msg config "window.opacity = ${opacity}" >/dev/null 2>&1 || alacritty msg config -r >/dev/null 2>&1 &
    fi
}

# If executed directly as a script (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    apply_terminal_opacity "$@"
fi
