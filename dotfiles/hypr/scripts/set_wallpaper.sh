#!/usr/bin/env bash

WALL="$1"
FRAME_CACHE="/tmp/wallpaper_frame.jpg"

echo "$WALL" > ~/.cache/current_wallpaper.txt

# 1. Clear out competing video engines
pkill -f mpvpaper 2>/dev/null

# 2. Handle the background graphics engine cleanly
if [[ "$WALL" =~ \.(mp4|mkv|webm)$ ]]; then
    pkill -f awww-daemon 2>/dev/null
    mpvpaper -o "no-audio --loop-playlist --hwdec=vaapi --panscan=1.0" '*' "$WALL" > /dev/null 2>&1 &
    
    ffmpeg -y -ss 00:00:00.100 -i "$WALL" -vframes 1 -q:v 2 "$FRAME_CACHE" > /dev/null 2>&1
    SEED="$FRAME_CACHE"
else
    # Only launch the daemon if it isn't already active to preserve memory
    if ! pgrep -f "awww-daemon" > /dev/null; then
        awww-daemon --format xrgb > /dev/null 2>&1 &
        sleep 0.6 # Increased delay to give the socket proper time to initialize
    fi

    # Render image or GIF cleanly via awww
    awww img "$WALL" --transition-type simple --transition-step 90 > /dev/null 2>&1
    
    if [[ "$WALL" =~ \.gif$ ]]; then
        ffmpeg -y -ss 00:00:00.100 -i "$WALL" -vframes 1 -q:v 2 "$FRAME_CACHE" > /dev/null 2>&1
        SEED="$FRAME_CACHE"
    else
        SEED="$WALL"
    fi
fi

# 3. Dynamic color palette generation matrix
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