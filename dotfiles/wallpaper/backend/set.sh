#!/usr/bin/env bash
# ==============================================================================
# Wallpaper Subsystem - Display Renderer (set.sh)
# Renders images/animations via awww and video wallpapers via mpvpaper (systemd).
# Emits clean asynchronous event to independent theme engine (wallust).
# ==============================================================================
set -uo pipefail

TARGET_OUTPUTS=""
WALL=""
TRANS_TYPE="${AWWW_TRANSITION:-none}"
TRANS_DURATION="${AWWW_TRANSITION_DURATION:-0.0}"
TRANS_FPS="${AWWW_TRANSITION_FPS:-120}"
TRANS_BEZIER="${AWWW_TRANSITION_BEZIER:-.1,.9,.2,1}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--outputs)
            TARGET_OUTPUTS="$2"
            shift 2
            ;;
        --outputs=*)
            TARGET_OUTPUTS="${1#*=}"
            shift
            ;;
        *)
            if [ -z "$WALL" ]; then
                WALL="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$WALL" ]; then
    echo "Usage: $0 [--outputs <name>] <path-to-wallpaper>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALL="$(realpath -q "$WALL" 2>/dev/null || echo "$WALL")"
EXT="${WALL##*.}"
EXT="${EXT,,}"
BASENAME=$(basename "$WALL")

DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
WALL_STATE_DIR="$DESKTOP_STATE_DIR/wallpaper"
MODES_STATE_DIR="$DESKTOP_STATE_DIR/modes"
POWER_STATE_DIR="$DESKTOP_STATE_DIR/power"
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/mpvpaper" "$CACHE_DIR" "$WALL_STATE_DIR" "$MODES_STATE_DIR" "$POWER_STATE_DIR"

LOCKFILE="$CACHE_DIR/set_wallpaper.lock"
exec 8>"$LOCKFILE"
flock 8

WAS_KILLED=0
if [ -f "$MODES_STATE_DIR/wallpaper_killed" ] || [ -f "$CACHE_DIR/wallpaper_killed" ]; then
    WAS_KILLED=1
fi
rm -f "$MODES_STATE_DIR/wallpaper_killed" "$CACHE_DIR/wallpaper_killed"

atomic_write() {
    local target="$1"
    local content="$2"
    local dir
    dir="$(dirname "$target")"
    local tmp="$dir/.$(basename "$target").tmp.$$"
    printf '%s\n' "$content" > "$tmp"
    mv -f "$tmp" "$target"
}

CURRENT_TXT="$WALL_STATE_DIR/current_wallpaper.txt"
LAST_TXT="$WALL_STATE_DIR/last_wallpaper.txt"

# Update persistent state files atomically (tmp + mv in same dir)
if [ -s "$CURRENT_TXT" ]; then
    prev_wall="$(cat "$CURRENT_TXT" 2>/dev/null || true)"
    if [ -n "$prev_wall" ] && [ "$prev_wall" != "$WALL" ]; then
        atomic_write "$LAST_TXT" "$prev_wall"
    fi
fi
atomic_write "$CURRENT_TXT" "$WALL"
[ ! -s "$LAST_TXT" ] && atomic_write "$LAST_TXT" "$WALL"
[ -z "${FORCE_CYCLE:-}" ] && rm -f "$CACHE_DIR/target_wallpaper.txt"

# Resolve target outputs once for both video and awww pipelines
RESOLVED_OUTPUTS=()
if [ -n "$TARGET_OUTPUTS" ] && [ "$TARGET_OUTPUTS" != "all" ]; then
    IFS=',' read -ra RESOLVED_OUTPUTS <<< "$TARGET_OUTPUTS"
elif command -v hyprctl >/dev/null 2>&1; then
    while IFS= read -r m; do
        [ -n "$m" ] && RESOLVED_OUTPUTS+=("$m")
    done < <(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
fi
OUT_JOINED=$(IFS=','; echo "${RESOLVED_OUTPUTS[*]}")

# 1. Video & Animated Wallpapers (Handled via systemd user template unit mpvpaper@<out>)
if [[ "$EXT" =~ ^(mp4|mkv|mov|webm|gif)$ ]]; then
    WALL_TARGET="$WALL"
    if [[ "$EXT" == "gif" ]]; then
        GIF_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/converted_gifs"
        target_mp4="$GIF_CACHE_DIR/${BASENAME%.*}.mp4"
        if [ -s "$target_mp4" ]; then
            WALL_TARGET="$target_mp4"
        elif [ -s "$GIF_CACHE_DIR/$BASENAME.mp4" ]; then
            WALL_TARGET="$GIF_CACHE_DIR/$BASENAME.mp4"
        else
            # Play GIF directly with mpvpaper instantly (0ms delay), convert to MP4 in background for future zero-power playback
            (
                mkdir -p "$GIF_CACHE_DIR"
                if command -v ffmpeg >/dev/null 2>&1; then
                    ffmpeg -hide_banner -loglevel error -y -i "$WALL" -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -an "$target_mp4" 2>/dev/null || true
                fi
            ) &
        fi
    fi

    if [ "${#RESOLVED_OUTPUTS[@]}" -eq 0 ]; then
        RESOLVED_OUTPUTS=("eDP-1")
    fi

    for out in "${RESOLVED_OUTPUTS[@]}"; do
        [ -n "$out" ] || continue
        # Write environment file atomically for mpvpaper@<out>.service
        ENV_FILE="$STATE_DIR/mpvpaper/${out}.env"
        TMP_ENV="${ENV_FILE}.tmp"
        echo "WALLPAPER_VIDEO=\"$WALL_TARGET\"" > "$TMP_ENV"
        mv -f "$TMP_ENV" "$ENV_FILE"

        # Clear awww layer on this output and restart systemd-managed mpvpaper
        command -v awww >/dev/null 2>&1 && awww clear -o "$out" >/dev/null 2>&1 || true
        systemctl --user restart "mpvpaper@$out" 2>/dev/null || true

        # Robust fallback: if systemd unit is not active, launch mpvpaper directly
        if ! systemctl --user is-active --quiet "mpvpaper@$out" 2>/dev/null; then
            pkill -f "mpvpaper.*$out" 2>/dev/null || true
            if command -v mpvpaper >/dev/null 2>&1; then
                mpvpaper -p -o "no-audio --load-scripts=no --loop-file=inf --loop-playlist=inf --hwdec=auto-safe --panscan=1.0" "$out" "$WALL_TARGET" 8>&- >/dev/null 2>&1 &
                disown $! 2>/dev/null || true
            fi
        fi
    done
else
    # 2. Static Images (Handled natively via awww)
    # Stop mpvpaper on targeted outputs before pushing image to awww
    if [ -n "$TARGET_OUTPUTS" ] && [ "$TARGET_OUTPUTS" != "all" ]; then
        for out in "${RESOLVED_OUTPUTS[@]}"; do
            [ -n "$out" ] || continue
            systemctl --user stop "mpvpaper@$out" 2>/dev/null || true
            pkill -f "mpvpaper.*$out" 2>/dev/null || true
            rm -f "$STATE_DIR/mpvpaper/${out}.env"
        done
    else
        systemctl --user stop "mpvpaper@*" 2>/dev/null || true
        pkill -f "mpvpaper" 2>/dev/null || true
        rm -rf "$STATE_DIR/mpvpaper"
    fi

    # Ensure awww daemon is active
    if (command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet awww-daemon) || [ -n "$(pidof .awww-daemon-wrapped 2>/dev/null || true)" ]; then
        : # Running under systemd or active process
    else
        "$SCRIPT_DIR/ensure_awww.sh" 8>&- 2>/dev/null || true
    fi

    if command -v awww >/dev/null 2>&1; then
        AWWW_ARGS=(
            --resize crop
            --transition-type "$TRANS_TYPE"
            --transition-step 255
            --transition-duration "$TRANS_DURATION"
            --transition-fps "$TRANS_FPS"
            --transition-bezier "$TRANS_BEZIER"
            --filter Bilinear
        )
        if [ -n "$OUT_JOINED" ]; then
            AWWW_ARGS+=(--outputs "$OUT_JOINED")
        elif [ -n "$TARGET_OUTPUTS" ] && [ "$TARGET_OUTPUTS" != "all" ]; then
            AWWW_ARGS+=(--outputs "$TARGET_OUTPUTS")
        fi

        awww img "${AWWW_ARGS[@]}" "$WALL" > /dev/null 2>&1
    fi
fi

# Release flock
flock -u 8 2>/dev/null || true
exec 8>&- 2>/dev/null || true

# Restore compositor visual transparency after wallpaper is active
if [ "$WAS_KILLED" -eq 1 ]; then
    STATE_CTL="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
    [ -x "$STATE_CTL" ] && bash "$STATE_CTL" set modes.wallpaperKilled false 2>/dev/null || true
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        CURRENT_PROFILE="$(cat "$POWER_STATE_DIR/profile" 2>/dev/null || echo "")"
        if [ "$CURRENT_PROFILE" != "power-saver" ] && [ ! -f "$MODES_STATE_DIR/gaming_mode" ]; then
            hyprctl eval "hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } }, animations = { enabled = true } })" >/dev/null 2>&1 || true
            hyprctl reload >/dev/null 2>&1 || true
        fi
        bash "$HOME/nix/dotfiles/wallust/terminal-opacity.sh" --reload 2>/dev/null || true
    fi
fi

# 3. Clean Decoupled Theme Handoff (wallust)
# Derived primary/internal connector prefix check using grep -E
internal_mon=""
if command -v hyprctl >/dev/null 2>&1; then
    internal_mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null | grep -E '^(eDP|LVDS|DSI)' | head -n 1 || true)
fi

should_run_wallust=0
if [ -z "$TARGET_OUTPUTS" ] || [ "$TARGET_OUTPUTS" = "all" ]; then
    should_run_wallust=1
elif [ -n "$internal_mon" ] && [[ ",$TARGET_OUTPUTS," == *",$internal_mon,"* ]]; then
    should_run_wallust=1
fi

if [ "$should_run_wallust" -eq 1 ]; then
    THEME_PID_FILE="/tmp/wallust_theme_handoff.pid"
    if [ -f "$THEME_PID_FILE" ]; then
        old_pid=$(cat "$THEME_PID_FILE" 2>/dev/null || true)
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null || true
        fi
    fi

    (
        THUMB_DIR="$CACHE_DIR/quickshell/wallpaper_picker/thumbs"
        SEED=""
        if [ -f "$THUMB_DIR/$BASENAME.jpg" ]; then
            SEED="$THUMB_DIR/$BASENAME.jpg"
        elif [ -f "$THUMB_DIR/$BASENAME" ]; then
            SEED="$THUMB_DIR/$BASENAME"
        else
            SEED="$(find "$THUMB_DIR" -name "*_${BASENAME}*" -print -quit 2>/dev/null || true)"
        fi
        [ -z "$SEED" ] && SEED="$WALL"

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

        THEME_ENGINE="${THEME_ENGINE:-$HOME/.config/wallust/generate.sh}"
        [ ! -x "$THEME_ENGINE" ] && THEME_ENGINE="$HOME/nix/dotfiles/wallust/generate.sh"
        if [ -x "$THEME_ENGINE" ]; then
            "$THEME_ENGINE" "$SEED" >/dev/null 2>&1
        fi
        rm -f "$THEME_PID_FILE" 2>/dev/null || true
    ) &
    echo $! > "$THEME_PID_FILE" 2>/dev/null || true
fi
