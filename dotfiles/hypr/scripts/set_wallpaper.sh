# ==> /home/realdhiru/nix/dotfiles/hypr/scripts/set_wallpaper.sh <==
#!/usr/bin/env bash

WALL="$1"

# Guard clause to safely exit if invoked without arguments
if [ -z "$WALL" ]; then
    exit 1
fi

# Normalize extension to lowercase for safe, case-insensitive routing
EXT="${WALL##*.}"
EXT="${EXT,,}"
BASENAME=$(basename "$WALL")

# 1. Update the wallpaper state cache file instantly
mkdir -p "$HOME/.cache"
echo "$WALL" > "$HOME/.cache/current_wallpaper.txt"

# 2. INSTANT VISUAL PATHWAY (Zero blocking delays, Strict Mutual Exclusion)
if [[ "$EXT" =~ ^(mp4|mkv|webm)$ ]]; then
    # Kill images before starting video
    pkill -f awww-daemon 2>/dev/null
    pkill -f mpvpaper 2>/dev/null
    mpvpaper -o "no-audio --loop-playlist --hwdec=vaapi --panscan=1.0" '*' "$WALL" > /dev/null 2>&1 &
else
    # Kill video before starting image
    pkill -f mpvpaper 2>/dev/null
    # Push the image to the persistent daemon instantly with a fast fade
    awww img "$WALL" \
        --transition-type fade \
        --transition-step 255 \
        --transition-duration 0.1 \
        --transition-fps 60 > /dev/null 2>&1
fi

# 3. ISOLATED WORKER THREAD (Forks immediately)
(
    # Check if a fast, low-res thumbnail already exists in the QS cache
    THUMB_DIR="$HOME/.cache/quickshell/wallpaper_picker/thumbs"
    CACHED_THUMB="$THUMB_DIR/$BASENAME"
    if [[ "$EXT" =~ ^(mp4|mkv|webm)$ ]]; then
        CACHED_THUMB="$THUMB_DIR/$BASENAME.jpg"
    fi

    # Use a PID-isolated temp file
    FRAME_CACHE="/tmp/wallpaper_frame_$$.jpg"
    trap 'rm -f "$FRAME_CACHE"' EXIT

    if [ -f "$CACHED_THUMB" ]; then
        # FAST PATH: The UI has already generated a 400x400 thumbnail. Use it directly for color math.
        SEED="$CACHED_THUMB"
    else
        # SLOW PATH: Generate a temporary frame from the raw file
        if [[ "$EXT" =~ ^(mp4|mkv|webm)$ ]]; then
            ffmpeg -y -ss 00:00:00.100 -i "$WALL" -vframes 1 -q:v 8 -vf "scale=400:-1" "$FRAME_CACHE" > /dev/null 2>&1
            SEED="$FRAME_CACHE"
        elif [[ "$EXT" == "gif" ]]; then
            ffmpeg -y -i "$WALL" -vframes 1 -q:v 8 -vf "scale=400:-1" "$FRAME_CACHE" > /dev/null 2>&1
            SEED="$FRAME_CACHE"
        else
            SEED="$WALL"
        fi
    fi

    # High-speed localized color analysis (Now safely operating on a max 400px image, not 4K)
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