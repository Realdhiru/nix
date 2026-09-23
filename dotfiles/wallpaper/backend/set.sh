#!/usr/bin/env bash
# ==============================================================================
# Wallpaper Subsystem - Display Renderer (set.sh)
# Renders images/animations via awww and video wallpapers via mpvpaper.
# Emits clean asynchronous event to independent theme engine.
# ==============================================================================
set -uo pipefail

WALL="${1:-}"
if [ -z "$WALL" ]; then
    echo "Usage: $0 <path-to-wallpaper>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALL="$(realpath -q "$WALL" 2>/dev/null || echo "$WALL")"
EXT="${WALL##*.}"
EXT="${EXT,,}"
BASENAME=$(basename "$WALL")

# 1. Update wallpaper state caches
mkdir -p "$HOME/.cache"
if [ -f "$HOME/.cache/current_wallpaper.txt" ]; then
    OLD_WALL="$(cat "$HOME/.cache/current_wallpaper.txt" 2>/dev/null || true)"
    if [ -n "$OLD_WALL" ] && [ "$OLD_WALL" != "$WALL" ] && [ -f "$OLD_WALL" ]; then
        echo "$OLD_WALL" > "$HOME/.cache/previous_wallpaper.txt"
    fi
fi
echo "$WALL" > "$HOME/.cache/current_wallpaper.txt"
echo "$WALL" > "$HOME/.cache/last_wallpaper.txt"

WAS_KILLED=0
[ -f "$HOME/.cache/wallpaper_killed" ] && WAS_KILLED=1
rm -f "$HOME/.cache/wallpaper_killed"

# Restore blur, shadows, and animations if recovering from killed wallpaper
if [ "$WAS_KILLED" -eq 1 ] && command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    CURRENT_PROFILE="$(cat "$HOME/.cache/qs_power_profile" 2>/dev/null || cat /tmp/qs_power_profile 2>/dev/null || echo "")"
    if [ "$CURRENT_PROFILE" != "power-saver" ] && [ ! -f "$HOME/.cache/gaming_mode" ]; then
        hyprctl eval "hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } }, animations = { enabled = true } })" >/dev/null 2>&1 || true
    fi
fi

# Serialize wallpaper switches to prevent overlapping process race conditions
LOCKFILE="$HOME/.cache/set_wallpaper.lock"
exec 8>"$LOCKFILE"
flock 8

# Abort if a newer wallpaper change arrived while waiting for lock
if [ "$(cat "$HOME/.cache/current_wallpaper.txt" 2>/dev/null)" != "$WALL" ]; then
    flock -u 8 2>/dev/null || true
    exec 8>&- 2>/dev/null || true
    exit 0
fi

mpvpaper_pids() {
    pidof .mpvpaper-wrapped 2>/dev/null || true
}

stop_mpvpaper() {
    local pids
    pids=$(mpvpaper_pids)
    if [ -z "$pids" ]; then
        rm -f /tmp/mpv-paper-socket "$HOME/.cache/mpvpaper.pid"
        return 0
    fi

    for pid in $pids; do kill -15 "$pid" 2>/dev/null || true; done
    for i in {1..10}; do [ -z "$(mpvpaper_pids)" ] && break; sleep 0.05; done

    pids=$(mpvpaper_pids)
    if [ -n "$pids" ]; then
        for pid in $pids; do kill -9 "$pid" 2>/dev/null || true; done
    fi
    rm -f /tmp/mpv-paper-socket "$HOME/.cache/mpvpaper.pid"
}

# 2. Render Wallpaper (Instant Visual Pathway)
if [[ "$EXT" =~ ^(mp4|mkv|mov|webm|gif)$ ]]; then
    "$SCRIPT_DIR/ensure_awww.sh" --stop 8>&- 2>/dev/null || true
    stop_mpvpaper
    
    WALL_TARGET="$WALL"
    if [[ "$EXT" == "gif" ]]; then
        GIF_CACHE_DIR="$HOME/.cache/converted_gifs"
        mkdir -p "$GIF_CACHE_DIR"
        WALL_TARGET="$GIF_CACHE_DIR/$BASENAME.mp4"
        if [ ! -s "$WALL_TARGET" ] && command -v ffmpeg >/dev/null 2>&1; then
            ffmpeg -hide_banner -loglevel error -y -i "$WALL" -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -preset veryfast -pix_fmt yuv420p -an "$WALL_TARGET" 8>&-
            [ ! -s "$WALL_TARGET" ] && WALL_TARGET="$WALL"
        fi
    fi

    if command -v mpvpaper >/dev/null 2>&1; then
        mpvpaper -o "no-audio --load-scripts=no --loop-file=inf --loop-playlist=inf --hwdec=auto-safe --panscan=1.0 --input-ipc-server=/tmp/mpv-paper-socket" '*' "$WALL_TARGET" 8>&- > /dev/null 2>&1 &
        disown $! 2>/dev/null || true
    fi
else
    stop_mpvpaper
    "$SCRIPT_DIR/ensure_awww.sh" 8>&- 2>/dev/null || true

    if command -v awww >/dev/null 2>&1; then
        awww img "$WALL" \
            --transition-type fade \
            --transition-step 255 \
            --transition-duration 0.08 \
            --transition-fps 60 > /dev/null 2>&1 &
    fi
fi

# Release lock now that wallpaper daemon has taken over
flock -u 8 2>/dev/null || true
exec 8>&- 2>/dev/null || true

# 3. Clean Decoupled Theme Handoff
(
    stored=$(cat "$HOME/.cache/current_wallpaper.txt" 2>/dev/null || true)
    [ "$stored" != "$WALL" ] && exit 0

    # Locate optimal seed image (thumbnail is faster for color extraction)
    THUMB_DIR="$HOME/.cache/quickshell/wallpaper_picker/thumbs"
    SEED=""
    if [ -f "$THUMB_DIR/$BASENAME.jpg" ]; then
        SEED="$THUMB_DIR/$BASENAME.jpg"
    elif [ -f "$THUMB_DIR/$BASENAME" ]; then
        SEED="$THUMB_DIR/$BASENAME"
    else
        SEED="$(find "$THUMB_DIR" -name "*_${BASENAME}*" -print -quit 2>/dev/null || true)"
    fi
    [ -z "$SEED" ] && SEED="$WALL"

    # If video, sample 1 frame for color sampling
    seed_ext="${SEED##*.}"
    seed_ext="${seed_ext,,}"
    if [[ "$seed_ext" =~ ^(mp4|mkv|mov|webm)$ ]]; then
        frame_seed="/tmp/thumb_${BASENAME}.jpg"
        if [ ! -s "$frame_seed" ] && command -v ffmpeg >/dev/null 2>&1; then
            ffmpeg -hide_banner -loglevel error -y -ss 00:00:01 -i "$SEED" -frames:v 1 -vf "scale=400:-1" "$frame_seed" 2>/dev/null || true
        fi
        [ -s "$frame_seed" ] && SEED="$frame_seed"
    fi

    is_light="dark"
    if [ -f "$HOME/.cache/theme/is_light.txt" ]; then
        [ "$(cat "$HOME/.cache/theme/is_light.txt" 2>/dev/null)" = "true" ] && is_light="light"
    fi

    # Trigger standalone theme engine if present
    THEME_ENGINE="${THEME_ENGINE:-$HOME/.config/wallust/generate.sh}"
    [ ! -x "$THEME_ENGINE" ] && THEME_ENGINE="$HOME/nix/dotfiles/wallust/generate.sh"
    if [ -x "$THEME_ENGINE" ]; then
        "$THEME_ENGINE" "$SEED" "$is_light" >/dev/null 2>&1
    fi
) &
