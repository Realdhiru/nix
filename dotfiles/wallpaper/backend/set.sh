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

if [ "$WAS_KILLED" -eq 1 ]; then
    STATE_CTL="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
    [ -x "$STATE_CTL" ] && bash "$STATE_CTL" set modes.wallpaperKilled false 2>/dev/null || true
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        CURRENT_PROFILE="$(cat "$HOME/.cache/qs_power_profile" 2>/dev/null || cat /tmp/qs_power_profile 2>/dev/null || echo "")"
        if [ "$CURRENT_PROFILE" != "power-saver" ] && [ ! -f "$HOME/.cache/gaming_mode" ]; then
            hyprctl eval "hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } }, animations = { enabled = true } })" >/dev/null 2>&1 || true
        fi
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
    WALL_TARGET="$WALL"

    # Seamless hot-swap if mpvpaper is already running
    if [ -S /tmp/mpv-paper-socket ] && [ -n "$(mpvpaper_pids)" ]; then
        echo '{ "command": ["loadfile", "'"$WALL_TARGET"'"] }' | socat -t 0.5 - /tmp/mpv-paper-socket >/dev/null 2>&1 || true
    else
        stop_mpvpaper
        rm -f /tmp/mpv-paper-socket
        "$SCRIPT_DIR/ensure_awww.sh" --stop 8>&- 2>/dev/null || true
        if command -v mpvpaper >/dev/null 2>&1; then
            nohup mpvpaper -p -o "no-audio --load-scripts=no --loop-file=inf --loop-playlist=inf --hwdec=auto-safe --panscan=1.0 --input-ipc-server=/tmp/mpv-paper-socket" '*' "$WALL_TARGET" 8>&- > /dev/null 2>&1 &
            disown $! 2>/dev/null || true
        fi
    fi
else
    # Images & GIFs: hardware-accelerated smooth transitions via awww
    "$SCRIPT_DIR/ensure_awww.sh" 8>&- 2>/dev/null || true

    TRANS_TYPE="${2:-${AWWW_TRANSITION:-fade}}"
    TRANS_DURATION="${3:-${AWWW_TRANSITION_DURATION:-0.18}}"
    TRANS_FPS="${4:-${AWWW_TRANSITION_FPS:-120}}"
    TRANS_BEZIER="${AWWW_TRANSITION_BEZIER:-.1,.9,.2,1}"

    if command -v awww >/dev/null 2>&1; then
        awww img "$WALL" \
            --resize crop \
            --transition-type "$TRANS_TYPE" \
            --transition-duration "$TRANS_DURATION" \
            --transition-fps "$TRANS_FPS" \
            --transition-bezier "$TRANS_BEZIER" > /dev/null 2>&1
    fi

    # Terminate mpvpaper only after awww has rendered the new wallpaper
    stop_mpvpaper
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

    # If video or GIF, sample 1 frame for ultra-fast color sampling
    seed_ext="${SEED##*.}"
    seed_ext="${seed_ext,,}"
    if [[ "$seed_ext" =~ ^(mp4|mkv|mov|webm)$ ]]; then
        frame_seed="/tmp/thumb_${BASENAME}.jpg"
        if [ ! -s "$frame_seed" ] && command -v ffmpeg >/dev/null 2>&1; then
            ffmpeg -hide_banner -loglevel error -y -ss 00:00:01 -i "$SEED" -frames:v 1 -vf "scale=400:-1" "$frame_seed" 2>/dev/null || true
        fi
        [ -s "$frame_seed" ] && SEED="$frame_seed"
    elif [[ "$seed_ext" == "gif" ]]; then
        frame_seed="/tmp/thumb_${BASENAME}.jpg"
        if [ ! -s "$frame_seed" ] && command -v magick >/dev/null 2>&1; then
            magick "${SEED}[0]" -resize 400x400\> "$frame_seed" 2>/dev/null || true
        fi
        [ -s "$frame_seed" ] && SEED="$frame_seed"
    fi

    # Cancel any previous in-flight theme generation to prevent CPU congestion during rapid switches
    THEME_PID_FILE="/tmp/wallust_theme_handoff.pid"
    if [ -f "$THEME_PID_FILE" ]; then
        old_pid=$(cat "$THEME_PID_FILE" 2>/dev/null || true)
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null || true
        fi
    fi

    # Trigger standalone theme engine if present
    THEME_ENGINE="${THEME_ENGINE:-$HOME/.config/wallust/generate.sh}"
    [ ! -x "$THEME_ENGINE" ] && THEME_ENGINE="$HOME/nix/dotfiles/wallust/generate.sh"
    if [ -x "$THEME_ENGINE" ]; then
        "$THEME_ENGINE" "$SEED" >/dev/null 2>&1
    fi
    rm -f "$THEME_PID_FILE" 2>/dev/null || true
) &
echo $! > /tmp/wallust_theme_handoff.pid 2>/dev/null || true
