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

# Serialize wallpaper switches to prevent overlapping process race conditions
LOCKFILE="$HOME/.cache/set_wallpaper.lock"
exec 8>"$LOCKFILE"
flock 8

# If a newer wallpaper change arrived while waiting for lock, abort stale request
if [ "$(cat "$HOME/.cache/current_wallpaper.txt" 2>/dev/null)" != "$WALL" ]; then
    flock -u 8 2>/dev/null || true
    exec 8>&- 2>/dev/null || true
    exit 0
fi

mpvpaper_pids() {
    pidof .mpvpaper-wrapped 2>/dev/null || true
}

# Reliable teardown helper for mpvpaper (handles NixOS .mpvpaper-wrapped binary name)
stop_mpvpaper() {
    local pids pid
    pids=$(mpvpaper_pids)
    if [ -z "$pids" ]; then
        rm -f /tmp/mpv-paper-socket "$HOME/.cache/mpvpaper.pid"
        return 0
    fi

    for pid in $pids; do
        kill -15 "$pid" 2>/dev/null || true
    done

    for i in {1..10}; do
        [ -z "$(mpvpaper_pids)" ] && break
        sleep 0.05
    done

    pids=$(mpvpaper_pids)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            kill -9 "$pid" 2>/dev/null || true
        done
        for i in {1..10}; do
            [ -z "$(mpvpaper_pids)" ] && break
            sleep 0.05
        done
    fi

    rm -f /tmp/mpv-paper-socket "$HOME/.cache/mpvpaper.pid"
}

# 2. INSTANT VISUAL PATHWAY (Zero blocking delays, Strict Mutual Exclusion)
if [[ "$EXT" =~ ^(mp4|mkv|mov|webm|gif)$ ]]; then
    # Kill images before starting video/gif
    # (daemon teardown centralized in ensure_awww.sh)
    "$HOME/.config/hypr/scripts/ensure_awww.sh" --stop 8>&-
    stop_mpvpaper
    
    WALL_TARGET="$WALL"
    if [[ "$EXT" == "gif" ]]; then
        GIF_CACHE_DIR="$HOME/.cache/converted_gifs"
        mkdir -p "$GIF_CACHE_DIR"
        WALL_TARGET="$GIF_CACHE_DIR/$BASENAME.mp4"
        if [ ! -f "$WALL_TARGET" ]; then
            # Convert GIF to MP4 on first run to enable hardware video decoding (VPU)
            ffmpeg -hide_banner -loglevel error -y -i "$WALL" -c:v libx264 -preset veryfast -pix_fmt yuv420p -an "$WALL_TARGET" 8>&-
        fi
    fi

    mpvpaper -o "no-audio --loop-playlist --hwdec=vaapi --panscan=1.0 --input-ipc-server=/tmp/mpv-paper-socket" '*' "$WALL_TARGET" 8>&- > /dev/null 2>&1 &

    # Inherit Power-Saver paused state if currently active
    CURRENT_PROF=$(cat /tmp/qs_requested_profile 2>/dev/null || echo "")
    if [ "$CURRENT_PROF" = "power-saver" ]; then
        (
            for i in {1..10}; do
                if [ -S /tmp/mpv-paper-socket ]; then
                    echo '{ "command": ["set_property", "pause", true] }' | socat - /tmp/mpv-paper-socket 2>/dev/null || true
                    break
                fi
                sleep 0.05
            done
        ) 8>&- &
    fi
else
    # Kill video before starting image
    stop_mpvpaper

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
    # Fix: ensure the daemon is actually alive before pushing an image.
    # Daemon start/readiness/stale-socket recovery is centralized in
    # ensure_awww.sh (single source of truth for the daemon lifecycle).
    "$HOME/.config/hypr/scripts/ensure_awww.sh" 8>&-

    # Push the image to the persistent daemon instantly with a fast fade
    if ! awww img "$WALL" \
        --transition-type fade \
        --transition-step 255 \
        --transition-duration 0.1 \
        --transition-fps 60 > /dev/null 2>&1; then
        
        # FALLBACK: If awww fails (e.g., unsupported format, fake extension, or crashes), fallback to mpvpaper
        "$HOME/.config/hypr/scripts/ensure_awww.sh" --stop 8>&-
        stop_mpvpaper
        mpvpaper -o "no-audio --loop-playlist --hwdec=auto --panscan=1.0" '*' "$WALL" 8>&- > /dev/null 2>&1 &
    fi
fi

# Release lock now that wallpaper daemon is started
flock -u 8 2>/dev/null || true
exec 8>&- 2>/dev/null || true

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

    # Calculate saturation and lightness to intelligently theme grayscale images
    eval $(magick "$SEED[0]" -resize 16x16 -colorspace HSL -format "sat=%[fx:mean.g*100]; lum=%[fx:mean.b*100]" info: 2>/dev/null)
    if [ -z "$sat" ] || [ -z "$lum" ]; then
        sat=100
        lum=50
    fi

    # Color pipeline critical section. Workers fork per apply and all write
    # the SAME shared artifacts (qs_colors.json + every matugen template
    # output), so overlapping workers previously raced: the slow tail of an
    # earlier worker could land last and clobber the final wallpaper's palette.
    mkdir -p "$HOME/.cache/matugen"
    exec 9>"$HOME/.cache/matugen/color_worker.lock"
    flock 9

    stored=$(cat "$HOME/.cache/current_wallpaper.txt" 2>/dev/null)
    if [ "$stored" != "$WALL" ]; then
        exit 0
    fi

    # Smart Color Generation Algorithm
    if (( $(echo "$sat < 15" | bc -l) )); then
        # 1. Image is very desaturated (Grayscale / B&W)
        if (( $(echo "$lum < 40" | bc -l) || $(echo "$lum > 70" | bc -l) )); then
            # Pure B&W (very dark or very light): Force White primary accents in Dark Mode
            matugen color hex "#FFFFFF" --config "$HOME/nix/dotfiles/matugen/config.toml" --type scheme-monochrome -m dark > "/tmp/matugen.$$.log" 2>&1
        else
            # Medium-Grey: Extract its exact faint tint so it gets subtle colors instead of flat grey
            avg_color=$(magick "$SEED[0]" -resize 1x1 -format "%[hex:u]" info:)
            matugen color hex "#$avg_color" --config "$HOME/nix/dotfiles/matugen/config.toml" > "/tmp/matugen.$$.log" 2>&1
        fi
    else
        # 2. Normal colored wallpaper
        if ! matugen image "$SEED" --config "$HOME/nix/dotfiles/matugen/config.toml" --source-color-index 0 > "/tmp/matugen.$$.log" 2>&1; then
            # Failsafe: if matugen panics (e.g. multiple ambiguous colors without preference), force average color
            avg_color=$(magick "$SEED[0]" -resize 1x1 -format "%[hex:u]" info:)
            matugen color hex "#$avg_color" --config "$HOME/nix/dotfiles/matugen/config.toml" > "/tmp/matugen.$$.log" 2>&1
        fi
    fi
) &