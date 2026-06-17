#!/usr/bin/env bash
WALL="$1"

pkill mpvpaper 2>/dev/null
mpvpaper -o "no-audio --loop-playlist --hwdec=auto --panscan=1.0" '*' "$WALL" &

# 1. Bulletproof B&W Detection: Compare original image to a desaturated clone
# Outputs a value between 0.0 (perfect grayscale) and ~1.0 (highly colorful)
color_diff=$(magick "$WALL" \( +clone -modulate 100,0 \) -metric RMSE -compare -format "%[fx:error]" info: 2>&1)

# 2. Conditional generation based on color difference
# A threshold of 0.05 catches pure B&W, sketches, and grayscale images with slight compression noise
if (( $(echo "$color_diff < 0.05" | bc -l) )); then
    # WALLPAPER IS B&W: Bypass image extraction and force a pure neutral gray seed
    matugen color hex "#808080" \
      --config /home/realdhiru/nix/dotfiles/matugen/config.toml \
      --type scheme-fidelity > /tmp/matugen.log 2>&1

    ~/nix/dotfiles/matugen/extract_raw_colors.sh "$WALL"
else
    # WALLPAPER HAS COLOR: Run normal palette generation
    matugen image "$WALL" \
      --config /home/realdhiru/nix/dotfiles/matugen/config.toml \
      --type scheme-fidelity \
      --source-color-index 0 > /tmp/matugen.log 2>&1
fi