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

# 2. Clear current wallpaper state file
rm -f "$HOME/.cache/current_wallpaper.txt"
touch "$HOME/.cache/current_wallpaper.txt"

# 3. Reset Matugen colors to clean pure neutral dark grey default theme (zero green/blue tint)
matugen color hex "#444444" --config "$HOME/nix/dotfiles/matugen/config.toml" --type scheme-monochrome -m dark >/dev/null 2>&1 || true
