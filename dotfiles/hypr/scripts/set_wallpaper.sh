#!/usr/bin/env bash
WALL="$1"
FRAME_CACHE="/tmp/wallpaper_frame.jpg"

echo "$WALL" > ~/.cache/current_wallpaper.txt

pkill mpvpaper 2>/dev/null
mpvpaper -o "no-audio --loop-playlist --hwdec=auto --panscan=1.0" '*' "$WALL" > /dev/null 2>&1 &

# Extract a static frame if the file is a video or animated graphic
if [[ "$WALL" =~ \.(mp4|mkv|webm|gif)$ ]]; then
    ffmpeg -y -ss 00:00:00.100 -i "$WALL" -vframes 1 -q:v 2 "$FRAME_CACHE" > /dev/null 2>&1
    SEED="$FRAME_CACHE"
else
    SEED="$WALL"
fi

# Calculate saturation against the static seed
sat=$(magick "$SEED" -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info:)

if (( $(echo "$sat < 5" | bc -l) )); then
    matugen color hex "#808080" \
      --config /home/realdhiru/nix/dotfiles/matugen/config.toml \
      --type scheme-fidelity > /tmp/matugen.log 2>&1

    ~/nix/dotfiles/matugen/extract_raw_colors.sh "$SEED"
else
    matugen image "$SEED" \
      --config /home/realdhiru/nix/dotfiles/matugen/config.toml \
      --type scheme-fidelity \
      --source-color-index 0 > /tmp/matugen.log 2>&1
fi