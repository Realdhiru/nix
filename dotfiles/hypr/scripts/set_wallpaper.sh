#!/usr/bin/env bash

WALL="$1"
FRAME_CACHE="/tmp/wallpaper_frame.jpg"

echo "$WALL" > ~/.cache/current_wallpaper.txt

# 1. Immediate UI presentation branch (Zero-blocking)
pkill -f mpvpaper 2>/dev/null

if [[ "$WALL" =~ \.(mp4|mkv|webm)$ ]]; then
    pkill -f awww-daemon 2>/dev/null
    mpvpaper -o "no-audio --loop-playlist --hwdec=vaapi --panscan=1.0" '*' "$WALL" > /dev/null 2>&1 &
    
    # Asynchronous thumbnail extraction
    (
        ffmpeg -y -ss 00:00:00.100 -i "$WALL" -vframes 1 -q:v 5 "$FRAME_CACHE" > /dev/null 2>&1
        matugen image "$FRAME_CACHE" --config /home/realdhiru/nix/dotfiles/matugen/config.toml --type scheme-fidelity --source-color-index 0 > /tmp/matugen.log 2>&1
    ) &
    exit 0
fi

# 2. Optimized Image / GIF pipeline via awww
if ! pgrep -f "awww-daemon" > /dev/null; then
    awww-daemon --format xrgb > /dev/null 2>&1 &
    sleep 0.4
fi

# Apply the background texture immediately to free up the display server pipeline
awww img "$WALL" --transition-type simple --transition-step 90 > /dev/null 2>&1

# 3. Offload heavy computation to an isolated background thread context
(
    if [[ "$WALL" =~ \.gif$ ]]; then
        # CRITICAL: Extract ONLY the first frame of the GIF to prevent full-file parsing overhead
        ffmpeg -y -i "$WALL" -vframes 1 -q:v 5 "$FRAME_CACHE" > /dev/null 2>&1
        SEED="$FRAME_CACHE"
    else
        SEED="$WALL"
    fi

    # Fast-path color matching calculation
    sat=$(magick "$SEED[0]" -resize 100x100 -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info:)

    if (( $(echo "$sat < 5" | bc -l) )); then
        matugen color hex "#808080" --config /home/realdhiru/nix/dotfiles/matugen/config.toml --type scheme-fidelity > /tmp/matugen.log 2>&1
        ~/nix/dotfiles/matugen/extract_raw_colors.sh "$SEED"
    else
        matugen image "$SEED" --config /home/realdhiru/nix/dotfiles/matugen/config.toml --type scheme-fidelity --source-color-index 0 > /tmp/matugen.log 2>&1
    fi
) &