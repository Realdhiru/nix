#!/usr/bin/env bash

WALL="$1"
FRAME_CACHE="/tmp/wallpaper_frame.jpg"

# Cache current target instantly
echo "$WALL" > ~/.cache/current_wallpaper.txt

# 1. Clear active video overlays
pkill -f mpvpaper 2>/dev/null

# 2. INSTANT CACHE PRESENTATION LAYER
# Dropped 'wave' and complex geometries. Using a lightweight 0.2 second fade transition.
awww img "$WALL" \
    --transition-type fade \
    --transition-step 255 \
    --transition-duration 0.2 \
    --transition-fps 60 > /dev/null 2>&1

# 3. DECOUPLED ASYNCHRONOUS WORKER THREAD
(
    if [[ "$WALL" =~ \.(mp4|mkv|webm)$ ]]; then
        mpvpaper -o "no-audio --loop-playlist --hwdec=vaapi --panscan=1.0" '*' "$WALL" > /dev/null 2>&1
        exit 0
    fi

    # Extract single frame anchors from animations for matugen safely
    if [[ "$WALL" =~ \.gif$ ]]; then
        ffmpeg -y -i "$WALL" -vframes 1 -q:v 8 "$FRAME_CACHE" > /dev/null 2>&1
        SEED="$FRAME_CACHE"
    else
        SEED="$WALL"
    fi

    # Downsampled color matrix extraction fast path
    sat=$(magick "$SEED[0]" -resize 16x16 -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info:)

    if (( $(echo "$sat < 5" | bc -l) )); then
        matugen color hex "#808080" --config /home/realdhiru/nix/dotfiles/matugen/config.toml --type scheme-fidelity > /tmp/matugen.log 2>&1
        ~/nix/dotfiles/matugen/extract_raw_colors.sh "$SEED"
    else
        matugen image "$SEED" --config /home/realdhiru/nix/dotfiles/matugen/config.toml --type scheme-fidelity --source-color-index 0 > /tmp/matugen.log 2>&1
    fi
) &