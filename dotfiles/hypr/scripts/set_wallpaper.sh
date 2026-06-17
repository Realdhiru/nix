#!/usr/bin/env bash
WALL="$1"

pkill mpvpaper 2>/dev/null
mpvpaper -o "no-audio --loop-playlist --hwdec=auto --panscan=1.0" '*' "$WALL" &

# 1. Calculate saturation up front
sat=$(magick "$WALL" -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info:)

# 2. Conditional generation based on color presence
if (( $(echo "$sat < 5" | bc -l) )); then
    # WALLPAPER IS B&W: Force Matugen to generate everything with your gray fallback colors
    matugen image "$WALL" \
      --config /home/realdhiru/nix/dotfiles/matugen/config.toml \
      --type scheme-fidelity \
      --source-color-index 0 \
      --custom-colors '{"primary": "#d3d3d3", "secondary": "#d3d3d3", "tertiary": "#d3d3d3"}' > /tmp/matugen.log 2>&1
      
    # Run your raw colors file to catch any stubborn JSON-only quickshell keys
    ~/nix/dotfiles/matugen/extract_raw_colors.sh "$WALL"
else
    # WALLPAPER HAS COLOR: Run normal palette generation
    matugen image "$WALL" \
      --config /home/realdhiru/nix/dotfiles/matugen/config.toml \
      --type scheme-fidelity \
      --source-color-index 0 > /tmp/matugen.log 2>&1
fi