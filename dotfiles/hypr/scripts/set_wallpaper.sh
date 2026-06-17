#!/usr/bin/env bash
WALL="$1"

pkill mpvpaper 2>/dev/null
mpvpaper -o "no-audio --loop-playlist --hwdec=auto --panscan=1.0" '*' "$WALL" &

# 1. Calculate saturation up front
sat=$(magick "$WALL" -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info:)

# 2. Conditional generation based on color presence
if (( $(echo "$sat < 5" | bc -l) )); then
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