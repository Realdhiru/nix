#!/usr/bin/env bash

WALL="$1"
FRAME_CACHE="/tmp/wallpaper_frame.jpg"

echo "$WALL" > ~/.cache/current_wallpaper.txt

# 1. Kill any competing desktop graphics daemons cleanly
pkill -f mpvpaper 2>/dev/null
pkill -f awww-daemon 2>/dev/null

# 2. Branch matching logic based on target format extensions
if [[ "$WALL" =~ \.(mp4|mkv|webm)$ ]]; then
    # VIDEO FLOW: Explicitly using Intel QSV hardware acceleration (vaapi)
    mpvpaper -o "no-audio --loop-playlist --hwdec=vaapi --panscan=1.0" '*' "$WALL" > /dev/null 2>&1 &
    
    # Extract static thumbnail frame anchor for theme generation engines
    ffmpeg -y -ss 00:00:00.100 -i "$WALL" -vframes 1 -q:v 2 "$FRAME_CACHE" > /dev/null 2>&1
    SEED="$FRAME_CACHE"
else
    # STATIC & GIF FLOW: Shifted to low-overhead awww engine to protect battery
    awww-daemon --format xrgb > /dev/null 2>&1 &
    sleep 0.3
    awww img "$WALL" --transition-type simple --transition-step 90 > /dev/null 2>&1
    
    # If it's a GIF, extract a thumbnail for matugen, otherwise use the image directly
    if [[ "$WALL" =~ \.gif$ ]]; then
        ffmpeg -y -ss 00:00:00.100 -i "$WALL" -vframes 1 -q:v 2 "$FRAME_CACHE" > /dev/null 2>&1
        SEED="$FRAME_CACHE"
    else
        SEED="$WALL"
    fi
fi

# 3. Structural Matugen/ImageMagick color calculation layout
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