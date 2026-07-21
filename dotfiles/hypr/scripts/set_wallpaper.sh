#!/usr/bin/env bash

WALL="$1"

# Guard clause to safely exit if invoked without arguments
if [ -z "$WALL" ]; then
    exit 1
fi

# Normalize extension to lowercase for safe, case-insensitive routing.
# Added "mov" here — it was already treated as a video everywhere else
# (wallpaper_thumbnail.sh, WallpaperPicker.qml's nameFilters/isVideoFile)
# but was missing from this regex, so a .mov wallpaper would silently fall
# into the image branch below and get handed to `awww img`, which cannot
# decode video and would just fail.
EXT="${WALL##*.}"
EXT="${EXT,,}"
BASENAME=$(basename "$WALL")

# 1. Update the wallpaper state cache file instantly
mkdir -p "$HOME/.cache"
echo "$WALL" > "$HOME/.cache/current_wallpaper.txt"

# 2. INSTANT VISUAL PATHWAY (Zero blocking delays, Strict Mutual Exclusion)
if [[ "$EXT" =~ ^(mp4|mkv|mov|webm)$ ]]; then
    # Kill images before starting video
    pkill -f awww-daemon 2>/dev/null
    pkill -f mpvpaper 2>/dev/null
    mpvpaper -o "no-audio --loop-playlist --hwdec=vaapi --panscan=1.0" '*' "$WALL" > /dev/null 2>&1 &
else
    # Kill video before starting image
    pkill -f mpvpaper 2>/dev/null

    # THE ACTUAL BUG: switching TO a video kills awww-daemon (correct — it
    # shouldn't be drawing behind mpvpaper). But switching FROM a video
    # back to an image never restarted it, so `awww img` below was being
    # sent to a daemon that no longer existed. Since its own output is
    # redirected to /dev/null, that failure was completely silent — the
    # picker would report success, matugen would still run against the
    # image and theme the rest of the system correctly, but the actual
    # background layer stayed whatever mpvpaper left behind (nothing, once
    # mpvpaper's surface was killed) — a permanently blank wallpaper until
    # something else happened to restart the daemon (e.g. a full reload).
    #
    # Fix: ensure the daemon is actually alive before pushing an image,
    # starting it if needed and giving it a moment to open its IPC socket.
    if ! pgrep -x awww-daemon > /dev/null 2>&1; then
        awww-daemon > /dev/null 2>&1 &
        # awww-daemon needs a brief moment to bind its IPC socket before
        # it can accept `awww img` calls; without this, the very first
        # apply right after a (re)start can race and silently no-op just
        # like the original bug, just intermittently instead of always.
        for i in $(seq 1 20); do
            awww query > /dev/null 2>&1 && break
            sleep 0.05
        done
    fi

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
    if [[ "$EXT" =~ ^(mp4|mkv|mov|webm)$ ]]; then
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
        if [[ "$EXT" =~ ^(mp4|mkv|mov|webm)$ ]]; then
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

    # replace the sat-check + if/else block with just:
matugen image "$SEED" --config "$HOME/nix/dotfiles/matugen/config.toml" --type scheme-expressive --source-color-index 0 > /tmp/matugen.log 2>&1
) &