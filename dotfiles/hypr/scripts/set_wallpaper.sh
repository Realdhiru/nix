#!/usr/bin/env bash
WALL="$1"

pkill mpvpaper 2>/dev/null
mpvpaper -o "no-audio --loop-playlist --hwdec=auto --panscan=1.0" '*' "$WALL" &

# 1. Run Matugen for all your other template files (Rofi, Cava, etc.)
matugen image "$WALL" \
  --config /home/realdhiru/nix/dotfiles/matugen/config.toml \
  --type scheme-fidelity \
  --source-color-index 0 > /tmp/matugen.log 2>&1

# 2. Force your custom extraction script LAST to override the colors for Quickshell
~/nix/dotfiles/matugen/extract_raw_colors.sh "$WALL"

touch ~/.config/wezterm/wezterm.lua