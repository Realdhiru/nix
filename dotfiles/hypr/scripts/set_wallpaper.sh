#!/usr/bin/env bash

WALL="$1"

# Guard clause to safely exit if invoked without arguments
if [ -z "$WALL" ]; then
    exit 1
fi

# Normalize extension to lowercase for safe, case-insensitive routing
EXT="${WALL##*.}"
EXT="${EXT,,}"

# 1. Update the wallpaper state cache file instantly
mkdir -p "$HOME/.cache"
echo "$WALL" > "$HOME/.cache/current_wallpaper.txt"

# 2. Kill running video engines to free up GPU channels
pkill -f mpvpaper 2>/dev/null

# 3. INSTANT VISUAL PATHWAY (Zero blocking delays)
if [[ "$EXT" =~ ^(mp4|mkv|webm)$ ]]; then
    pkill -f awww-daemon 2>/dev/null
    mpvpaper -o "no-audio --loop-playlist --hwdec=vaapi --panscan=1.0" '*' "$WALL" > /dev/null 2>&1 &
else
    # Push the image to the persistent daemon instantly with a fast fade
    awww img "$WALL" \
        --transition-type fade \
        --transition-step 255 \
        --transition-duration 0.1 \
        --transition-fps 60 > /dev/null 2>&1
fi

# 4. ISOLATED WORKER THREAD (Forks immediately; code below takes 0.00s of script execution time)
(
    # Use a PID-isolated temp file to prevent race conditions during rapid workspace/wallpaper switching
    FRAME_CACHE="/tmp/wallpaper_frame_$$.jpg"
    
    # Ensure atomic cleanup of the temp file when this specific subshell exits
    trap 'rm -f "$FRAME_CACHE"' EXIT

    # Fallback early if it's a raw video file
    if [[ "$EXT" =~ ^(mp4|mkv|webm)$ ]]; then
        ffmpeg -y -ss 00:00:00.100 -i "$WALL" -vframes 1 -q:v 8 "$FRAME_CACHE" > /dev/null 2>&1
        matugen image "$FRAME_CACHE" --config "$HOME/nix/dotfiles/matugen/config.toml" --type scheme-fidelity --source-color-index 0 > /tmp/matugen.log 2>&1
        exit 0
    fi

    # Optimize animation frame extraction
    if [[ "$EXT" == "gif" ]]; then
        # Extract ONLY the first frame to avoid parsing the entire animation file
        ffmpeg -y -i "$WALL" -vframes 1 -q:v 8 "$FRAME_CACHE" > /dev/null 2>&1
        SEED="$FRAME_CACHE"
    else
        SEED="$WALL"
    fi

    # High-speed localized color analysis using a tiny 16x16 sample matrix
    sat=$(magick "$SEED[0]" -resize 16x16 -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info: 2>/dev/null)

    # Failsafe: If magick fails (bad image/format), default to 100 to prevent 'bc' syntax errors
    if [ -z "$sat" ]; then
        sat=100
    fi

    if (( $(echo "$sat < 5" | bc -l) )); then
        matugen color hex "#808080" --config "$HOME/nix/dotfiles/matugen/config.toml" --type scheme-fidelity > /tmp/matugen.log 2>&1
        "$HOME/nix/dotfiles/matugen/extract_raw_colors.sh" "$SEED"
    else
        matugen image "$SEED" --config "$HOME/nix/dotfiles/matugen/config.toml" --type scheme-fidelity --source-color-index 0 > /tmp/matugen.log 2>&1
    fi
) &