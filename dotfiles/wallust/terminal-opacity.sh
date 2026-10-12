#!/usr/bin/env bash
# Keep terminal background translucency in sync with the QuickShell visibility mode.

apply_terminal_opacity() {
    local opacity="0.30"
    local state_file="$HOME/.cache/quickshell/state.json"
    local alacritty_colors="$HOME/.cache/theme/alacritty-colors.toml"

    if [ -f "$state_file" ] && [ "$(jq -r '.ui.themeMode // "dark"' "$state_file" 2>/dev/null || true)" = "light" ]; then
        opacity="0.60"
    fi

    if [ -f "$alacritty_colors" ]; then
        sed -i -E "s/^opacity = [0-9.]+$/opacity = ${opacity}/" "$alacritty_colors"
    fi

    if [ "${1:-}" = "--reload" ]; then
        alacritty msg config -r >/dev/null 2>&1 &
    fi
}
