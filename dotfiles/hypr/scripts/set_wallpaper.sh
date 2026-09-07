#!/usr/bin/env bash

WALL="${1:-}"

# Guard clause to safely exit if invoked without arguments
if [ -z "$WALL" ]; then
    exit 1
fi

# Resolve canonical path to prevent ephemeral symlinks (.cache) from persisting
WALL="$(realpath -q "$WALL" 2>/dev/null || echo "$WALL")"

# Normalize extension to lowercase for safe, case-insensitive routing
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

# Reliable teardown helper for mpvpaper
stop_mpvpaper() {
    local pids
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

# 2. INSTANT VISUAL PATHWAY FIRST (Zero blocking delays, immediate render)
if [[ "$EXT" =~ ^(mp4|mkv|mov|webm|gif)$ ]]; then
    "$HOME/.config/hypr/scripts/ensure_awww.sh" --stop 8>&-
    stop_mpvpaper
    
    WALL_TARGET="$WALL"
    if [[ "$EXT" == "gif" ]]; then
        GIF_CACHE_DIR="$HOME/.cache/converted_gifs"
        mkdir -p "$GIF_CACHE_DIR"
        WALL_TARGET="$GIF_CACHE_DIR/$BASENAME.mp4"
        if [ ! -s "$WALL_TARGET" ]; then
            ffmpeg -hide_banner -loglevel error -y -i "$WALL" -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -preset veryfast -pix_fmt yuv420p -an "$WALL_TARGET" 8>&-
            [ ! -s "$WALL_TARGET" ] && WALL_TARGET="$WALL"
        fi
    fi

    mpvpaper -o "no-audio --load-scripts=no --loop-file=inf --loop-playlist=inf --hwdec=auto-safe --panscan=1.0 --input-ipc-server=/tmp/mpv-paper-socket" '*' "$WALL_TARGET" 8>&- > /dev/null 2>&1 &
    disown $! 2>/dev/null || true
else
    stop_mpvpaper
    "$HOME/.config/hypr/scripts/ensure_awww.sh" 8>&-

    # Trigger awww without blocking the color worker
    awww img "$WALL" \
        --transition-type fade \
        --transition-step 255 \
        --transition-duration 0.08 \
        --transition-fps 60 > /dev/null 2>&1 &
fi

# Release lock now that wallpaper daemon is triggered
flock -u 8 2>/dev/null || true
exec 8>&- 2>/dev/null || true

# 3. PARALLEL MATUGEN COLOR PIPELINE (Runs concurrently in background)
(
    mkdir -p "$HOME/.cache/matugen"
    exec 9>"$HOME/.cache/matugen/color_worker.lock"
    flock 9

    stored=$(cat "$HOME/.cache/current_wallpaper.txt" 2>/dev/null)
    [ "$stored" != "$WALL" ] && exit 0

    # Locate thumbnail (<3ms)
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

    # Guard against matugen crashing if SEED is a video
    seed_ext="${SEED##*.}"
    seed_ext="${seed_ext,,}"
    if [[ "$seed_ext" =~ ^(mp4|mkv|mov|webm)$ ]]; then
        frame_seed="/tmp/thumb_${BASENAME}.jpg"
        if [ ! -s "$frame_seed" ]; then
            ffmpeg -hide_banner -loglevel error -y -ss 00:00:01 -i "$SEED" -frames:v 1 -vf "scale=400:-1" "$frame_seed" 2>/dev/null || true
        fi
        [ -s "$frame_seed" ] && SEED="$frame_seed"
    fi

    # Rapid top luminance assessment for topbar contrast
    eval $(magick "$SEED[0]" -crop 100%x15%+0+0 -colorspace HSL -format "top_lum=%[fx:mean.b*100]" info: 2>/dev/null || echo "top_lum=50")

    is_light="false"
    if (( $(echo "${top_lum:-50} > 55" | bc -l 2>/dev/null || echo 0) )); then
        is_light="true"
    fi
    echo "$is_light" > "$HOME/.cache/matugen/wallpaper_is_light.txt"

    # Intelligent color scheme extraction:
    # 1. B&W / desaturated / washed-out pale wallpapers (Sat < 18%) -> scheme-monochrome (prefers pure white #FFFFFF, zero fake cyan).
    # 2. Genuine colored wallpapers (Sat >= 18%) -> scheme-tonal-spot with matching dominant aesthetic color.
    read -r scheme_type source_color < <(
        matugen image "$SEED" --show-source-colors 2>/dev/null | python3 -c '
import sys, colorsys

def hex_to_hsv(h):
    h = h.lstrip("#")
    r, g, b = [int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
    return hue * 360, sat * 100, val * 100

lines = [l.strip() for l in sys.stdin if l.strip().startswith("#")]
if not lines:
    print("scheme-monochrome #808080")
    sys.exit(0)

h0, s0, v0 = hex_to_hsv(lines[0])
chosen = lines[0]
chosen_s = s0

# If dominant cluster is pitch black void (<18% val) and another candidate is colored, select it
if v0 < 18 and len(lines) > 1:
    for c in lines[1:]:
        ch, cs, cv = hex_to_hsv(c)
        if cv >= 18 and cs >= 18:
            chosen = c
            chosen_s = cs
            break

# If chosen color is desaturated / pale / washed out (HSV Sat < 18%):
# Prefer clean white monochrome (#FFFFFF) instead of letting M3 hallucinate blue
if chosen_s < 18:
    print("scheme-monochrome #808080")
else:
    print(f"scheme-tonal-spot {chosen}")
'
    )

    [ -z "$scheme_type" ] && scheme_type="scheme-tonal-spot"
    [ -z "$source_color" ] && source_color="#808080"

    matugen color hex "$source_color" --type "$scheme_type" --config "$HOME/nix/dotfiles/matugen/config.toml" > "/tmp/matugen.$$.log" 2>&1

    # Ensure isLight and topLuminance are preserved in the fresh qs_colors.json via sub-3ms jq
    jq --argjson il "$is_light" --arg tl "${top_lum:-50}" '. + {isLight: $il, topLuminance: ($tl|tonumber)}' \
        "$HOME/.cache/matugen/qs_colors.json" > "$HOME/.cache/matugen/qs_colors.json.tmp" 2>/dev/null && \
    mv "$HOME/.cache/matugen/qs_colors.json.tmp" "$HOME/.cache/matugen/qs_colors.json"
) &
