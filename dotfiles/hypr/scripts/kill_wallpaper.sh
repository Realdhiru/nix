#!/usr/bin/env bash

# 1. Stop all desktop wallpaper rendering daemons (awww and mpvpaper)
"$HOME/.config/hypr/scripts/ensure_awww.sh" --stop 2>/dev/null || true
pkill -15 -x .mpvpaper-wrapp 2>/dev/null || true
pkill -15 -x mpvpaper 2>/dev/null || true
pkill -f mpvpaper 2>/dev/null || true
rm -f /tmp/mpv-paper-socket "$HOME/.cache/mpvpaper.pid"

# 2. Clear current wallpaper state file
rm -f "$HOME/.cache/current_wallpaper.txt"
touch "$HOME/.cache/current_wallpaper.txt"

# 3. Reset Matugen colors to clean pure neutral dark grey default theme (zero green/blue tint)
matugen color hex "#444444" --config "$HOME/nix/dotfiles/matugen/config.toml" --type scheme-monochrome -m dark >/dev/null 2>&1 || true
