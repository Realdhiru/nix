#!/usr/bin/env bash

# 1. Stop all desktop wallpaper rendering daemons (awww and mpvpaper)
"$HOME/.config/hypr/scripts/ensure_awww.sh" --stop 2>/dev/null || true
pids=$(pidof .mpvpaper-wrapped 2>/dev/null || true)
if [ -n "$pids" ]; then
    for pid in $pids; do kill -15 "$pid" 2>/dev/null || true; done
    sleep 0.1
    pids=$(pidof .mpvpaper-wrapped 2>/dev/null || true)
    for pid in $pids; do kill -9 "$pid" 2>/dev/null || true; done
fi
rm -f /tmp/mpv-paper-socket "$HOME/.cache/mpvpaper.pid"

# 2. Clear current wallpaper state file (preserving last_wallpaper.txt for widget recall)
if [ -s "$HOME/.cache/current_wallpaper.txt" ]; then
    cp -f "$HOME/.cache/current_wallpaper.txt" "$HOME/.cache/last_wallpaper.txt" 2>/dev/null || true
fi
rm -f "$HOME/.cache/current_wallpaper.txt"
touch "$HOME/.cache/current_wallpaper.txt"

# 3. Reset Matugen colors to clean pure neutral dark grey default theme (zero green/blue tint)
matugen color hex "#444444" --config "$HOME/nix/dotfiles/matugen/config.toml" --type scheme-monochrome -m dark >/dev/null 2>&1 || true

# 4. Disable battery-draining GPU blur, shadows, animations and transparent alpha blending
hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0 }, animations = { enabled = false } })" >/dev/null 2>&1 || true
hyprctl eval "hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })" >/dev/null 2>&1 || true
touch "$HOME/.cache/wallpaper_killed"
