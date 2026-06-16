#!/usr/bin/env bash
WALL="$1"

pkill mpvpaper 2>/dev/null
mpvpaper -o "no-audio --loop-playlist --hwdec=auto --panscan=1.0" '*' "$WALL" &

# Force Matugen to use 'fidelity' which preserves the exact wallpaper shades
# We also point it to your existing config.toml to ensure all your templates (Rofi, Cava, WezTerm) still work
matugen image "$WALL" \
  --config /home/realdhiru/nix/dotfiles/matugen/config.toml \
  --type scheme-fidelity \
  --source-color-index 0 > /tmp/matugen.log 2>&1

touch ~/.config/wezterm/wezterm.lua