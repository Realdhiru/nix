#!/usr/bin/env bash
#
# wallpaper.sh -- Unified Wallpaper Management CLI
#
# Commands:
#   set <file>     Set active desktop wallpaper (handles images, gifs, videos)
#   boot           Initialize wallpaper on user login
#   kill           Kill active wallpaper daemons and reset theme to neutral
#   ensure [opts]  Ensure/restart awww-daemon lifecycle
#   thumb [file]   Generate thumbnails and quickshell flat links
#   watch          Background inotify watcher for ~/Pictures/Wallpapers
#   clean          Purge orphaned thumbnails and broken cache links
#

set -uo pipefail

CMD="${1:-boot}"
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALL_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
CACHE_DIR="$HOME/.cache/quickshell/wallpaper_picker"
THUMB_DIR="$CACHE_DIR/thumbs"
COLOR_DIR="$CACHE_DIR/colors_markers"
FLAT_DIR="$CACHE_DIR/flat"
GIF_DIR="$HOME/.cache/converted_gifs"
CURRENT_TXT="$HOME/.cache/current_wallpaper.txt"
LAST_TXT="$HOME/.cache/last_wallpaper.txt"

mkdir -p "$CACHE_DIR" "$THUMB_DIR" "$COLOR_DIR" "$FLAT_DIR" "$GIF_DIR"

# -----------------------------------------------------------------------------
# SUBCOMMAND: ensure
# -----------------------------------------------------------------------------
cmd_ensure() {
    exec "$SCRIPT_DIR/ensure_awww.sh" "$@"
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: clean
# -----------------------------------------------------------------------------
cmd_clean() {
    if [ -d "$FLAT_DIR" ]; then
        while IFS= read -r -d '' link; do
            local target
            target=$(readlink -f "$link" 2>/dev/null || true)
            if [ ! -e "$link" ] || [[ "$target" == *"/previews/"* ]] || [[ "$target" == *"/scripts/"* ]]; then
                local base
                base=$(basename "$link")
                local raw_name="${base#*_}"
                rm -f "$THUMB_DIR/$base" "$THUMB_DIR/$base.jpg" "$THUMB_DIR/$raw_name" "$THUMB_DIR/$raw_name.jpg" 2>/dev/null || true
                rm -f "$COLOR_DIR/${base}_"* "$COLOR_DIR/${raw_name}_"* 2>/dev/null || true
                rm -f "$GIF_DIR/${base}.mp4" "$GIF_DIR/${raw_name}.mp4" 2>/dev/null || true
                rm -f "$link" 2>/dev/null || true
            fi
        done < <(find "$FLAT_DIR" -type l -print0 2>/dev/null)
    fi

    if [ -d "$THUMB_DIR" ] && [ -d "$FLAT_DIR" ]; then
        for t in "$THUMB_DIR"/*; do
            [ -f "$t" ] || continue
            local t_name
            t_name=$(basename "$t")
            local raw="${t_name%.*}"
            if ! ls "$FLAT_DIR"/*"$raw"* 1>/dev/null 2>&1 && ! ls "$FLAT_DIR"/*"$t_name"* 1>/dev/null 2>&1; then
                rm -f "$t" "$COLOR_DIR/${raw}_"* 2>/dev/null || true
            fi
        done
    fi

    if [ -f "$CURRENT_TXT" ]; then
        local cur
        cur="$(cat "$CURRENT_TXT" 2>/dev/null || true)"
        if [ -n "$cur" ] && [ ! -f "$cur" ]; then
            rm -f "$CURRENT_TXT"
            cmd_boot
        fi
    fi
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: kill
# -----------------------------------------------------------------------------
cmd_kill() {
    "$SCRIPT_DIR/ensure_awww.sh" --stop 2>/dev/null || true
    local pids
    pids=$(pidof .mpvpaper-wrapped 2>/dev/null || true)
    if [ -n "$pids" ]; then
        for pid in $pids; do kill -15 "$pid" 2>/dev/null || true; done
        sleep 0.1
        pids=$(pidof .mpvpaper-wrapped 2>/dev/null || true)
        for pid in $pids; do kill -9 "$pid" 2>/dev/null || true; done
    fi
    rm -f /tmp/mpv-paper-socket "$HOME/.cache/mpvpaper.pid"

    if [ -s "$CURRENT_TXT" ]; then
        cp -f "$CURRENT_TXT" "$LAST_TXT" 2>/dev/null || true
    fi
    rm -f "$CURRENT_TXT"
    touch "$CURRENT_TXT"

    matugen color hex "#444444" --config "$HOME/nix/dotfiles/matugen/config.toml" --type scheme-monochrome -m dark >/dev/null 2>&1 || true

    hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0 } })" >/dev/null 2>&1 || true
    hyprctl eval "hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })" >/dev/null 2>&1 || true
    touch "$HOME/.cache/wallpaper_killed"
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: set
# -----------------------------------------------------------------------------
cmd_set() {
    exec "$SCRIPT_DIR/set_wallpaper.sh" "$@"
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: boot
# -----------------------------------------------------------------------------
cmd_boot() {
    local wall=""
    if [ -f "$CURRENT_TXT" ]; then
        local cached
        cached="$(cat "$CURRENT_TXT")"
        if [ -n "$cached" ] && [ -f "$cached" ] && [[ "$cached" != *"/previews/"* ]]; then
            wall="$cached"
        fi
    fi

    if [ -z "$wall" ]; then
        wall="$(find "$WALL_DIR" -not -path '*/.*' -not -path '*/previews/*' -not -path '*/scripts/*' -type f \( \
            -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o \
            -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o \
            -iname '*.mov' -o -iname '*.webm' \) -printf '%T@ %p\n' 2>/dev/null \
            | sort -rn | head -n 1 | cut -d' ' -f2-)"
    fi

    [ -n "$wall" ] || exit 0
    cmd_set "$wall"
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: thumb
# -----------------------------------------------------------------------------
cmd_thumb() {
    exec "$SCRIPT_DIR/wallpaper_thumbnail.sh" "$@"
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: watch
# -----------------------------------------------------------------------------
cmd_watch() {
    exec "$SCRIPT_DIR/wallpaper_watcher.sh" "$@"
}

# -----------------------------------------------------------------------------
# ROUTER
# -----------------------------------------------------------------------------
case "$CMD" in
    set)     cmd_set "$@" ;;
    boot)    cmd_boot "$@" ;;
    kill)    cmd_kill "$@" ;;
    ensure)  cmd_ensure "$@" ;;
    thumb)   cmd_thumb "$@" ;;
    watch)   cmd_watch "$@" ;;
    clean)   cmd_clean "$@" ;;
    *)
        if [ -f "$CMD" ]; then
            cmd_set "$CMD" "$@"
        else
            echo "Usage: wallpaper.sh [set <file>|boot|kill|ensure|thumb|watch|clean]" >&2
            exit 1
        fi
        ;;
esac
