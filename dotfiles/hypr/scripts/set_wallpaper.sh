#!/usr/bin/env bash
WALL="$1"

pkill mpvpaper 2>/dev/null
mpvpaper -o "no-audio --loop-playlist --hwdec=auto --panscan=1.0" '*' "$WALL" &

# 1. Run Matugen for all your templates
matugen image "$WALL" \
  --config /home/realdhiru/nix/dotfiles/matugen/config.toml \
  --type scheme-fidelity \
  --source-color-index 0 > /tmp/matugen.log 2>&1

# 2. SATURATION CHECK: Only run the override if the image is B&W
sat=$(magick "$WALL" -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info:)
if (( $(echo "$sat < 5" | bc -l) )); then
    ~/nix/dotfiles/matugen/extract_raw_colors.sh "$WALL"
fi

touch ~/.config/wezterm/wezterm.lua