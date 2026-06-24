#!/usr/bin/env bash

WALL="$1"
FRAME_CACHE="/tmp/wallpaper_frame.jpg"

# Cache current target immediately
echo "$WALL" > ~/.cache/current_wallpaper.txt

# 1. Clear out competing video engines
pkill -f mpvpaper 2>/dev/null

# 2. Handle immediate low-power wallpaper presentation
if ! pgrep -f "awww-daemon" > /dev/null; then
    awww-daemon --format xrgb > /dev/null 2>&1 &
    sleep 0.2
fi

# INSTANT TRANSITION: Using hardware accelerated wave geometry interpolation
awww img "$WALL" \
    --transition-type wave \
    --transition-angle 30 \
    --transition-step 120 \
    --transition-fps 60 > /dev/null 2>&1

# 3. BACKGROUND THE WORKER TASK (Everything below forks instantly so the script exits in 0.01s)
(
    if [[ "$WALL" =~ \.(mp4|mkv|webm)$ ]]; then
        # If it's a heavy video, fall back to mpvpaper over the static backdrop
        pkill -f awww-daemon 2>/dev/null
        mpvpaper -o "no-audio --loop-playlist --hwdec=vaapi --panscan=1.0" '*' "$WALL" > /dev/null 2>&1
        exit 0
    fi

    # Handle GIF extraction lazily
    if [[ "$WALL" =~ \.gif$ ]]; then
        ffmpeg -y -i "$WALL" -vframes 1 -q:v 8 "$FRAME_CACHE" > /dev/null 2>&1
        SEED="$FRAME_CACHE"
    else
        SEED="$WALL"
    fi

    # Fast-path localized downsampled saturation test
    sat=$(magick "$SEED[0]" -resize 30x30 -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info:)

    if (( $(echo "$sat < 5" | bc -l) )); then
        matugen color hex "#808080" --config /home/realdhiru/nix/dotfiles/matugen/config.toml --type scheme-fidelity > /tmp/matugen.log 2>&1
        ~/nix/dotfiles/matugen/extract_raw_colors.sh "$SEED"
    else
        matugen image "$SEED" --config /home/realdhiru/nix/dotfiles/matugen/config.toml --type scheme-fidelity --source-color-index 0 > /tmp/matugen.log 2>&1
    fi
) &