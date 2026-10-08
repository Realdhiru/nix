#!/usr/bin/env bash
# ==============================================================================
# Self-Contained Wallpaper Subsystem CLI (wallpaper.sh)
#
# Commands:
#   set <file>     Set active desktop wallpaper (images, gifs, videos)
#   boot           Initialize/restore wallpaper on login
#   kill           Kill active wallpaper daemons and apply neutral theme
#   ensure [opts]  Ensure/restart awww-daemon lifecycle
#   thumb [file]   Generate thumbnails and quickshell flat links
#   watch          Background inotify watcher for ~/Pictures/Wallpapers
#   clean          Purge orphaned thumbnails and broken cache links
#   search <query> Search online wallpapers via DuckDuckGo
# ==============================================================================
set -uo pipefail

CMD="${1:-boot}"
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$SCRIPT_DIR/backend"
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
    exec "$BACKEND/ensure_awww.sh" "$@"
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
    local state_ctl="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
    if [ -f "$HOME/.cache/wallpaper_killed" ]; then
        # TOGGLE BACK ON: Restore last active wallpaper (set.sh handles deleting wallpaper_killed and restoring blur/shadows)
        local target=""
        if [ -s "$LAST_TXT" ]; then
            target="$(cat "$LAST_TXT" 2>/dev/null || true)"
        elif [ -f "$HOME/.cache/last_wallpaper.txt" ]; then
            target="$(cat "$HOME/.cache/last_wallpaper.txt" 2>/dev/null || true)"
        fi
        if [ -n "$target" ] && [ -f "$target" ]; then
            cmd_set "$target" "none" "0.0" "120"
        else
            rm -f "$HOME/.cache/wallpaper_killed"
            cmd_boot
            if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
                hyprctl eval "hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } }, animations = { enabled = true } })" >/dev/null 2>&1 || true
            fi
        fi
        [ -x "$state_ctl" ] && bash "$state_ctl" set modes.wallpaperKilled false 2>/dev/null || true
        notify-send -a "Wallpaper" -u low "ON"
        return 0
    fi

    "$BACKEND/ensure_awww.sh" --stop 2>/dev/null || true
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
    elif [ -f "$HOME/.cache/current_wallpaper.txt" ]; then
        cp -f "$HOME/.cache/current_wallpaper.txt" "$LAST_TXT" 2>/dev/null || true
    fi
    rm -f "$CURRENT_TXT"
    touch "$CURRENT_TXT"

    # Decoupled neutral theme trigger
    THEME_ENGINE="${THEME_ENGINE:-$HOME/.config/wallust/generate.sh}"
    [ ! -x "$THEME_ENGINE" ] && THEME_ENGINE="$HOME/nix/dotfiles/wallust/generate.sh"
    if [ -x "$THEME_ENGINE" ]; then
        "$THEME_ENGINE" --neutral >/dev/null 2>&1 &
    fi

    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } }, animations = { enabled = true } })" >/dev/null 2>&1 || true
    fi
    touch "$HOME/.cache/wallpaper_killed"
    [ -x "$state_ctl" ] && bash "$state_ctl" set modes.wallpaperKilled true 2>/dev/null || true
    notify-send -a "Wallpaper" -u low "OFF"
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: set
# -----------------------------------------------------------------------------
cmd_set() {
    exec "$BACKEND/set.sh" "$@"
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: boot
# -----------------------------------------------------------------------------
cmd_boot() {
    if [ -f "$HOME/.cache/wallpaper_killed" ]; then
        cmd_kill
        exit 0
    fi

    local wall=""
    if [ -f "$CURRENT_TXT" ]; then
        local cached
        cached="$(cat "$CURRENT_TXT" 2>/dev/null || true)"
        if [ -n "$cached" ] && [ -f "$cached" ] && [[ "$cached" != *"/previews/"* ]]; then
            wall="$cached"
        fi
    fi

    if [ -z "$wall" ]; then
        wall="$(find "$WALL_DIR" -not -path '*/.*' -not -path '*/previews/*' -not -path '*/scripts/*' -type f \( \
            -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o \
            -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o \
            -iname '*.mov' -o -iname '*.webm' \) -printf '%T@ %p\n' 2>/dev/null \
            | sort -rn | head -n 1 | cut -d' ' -f2- || true)"
    fi

    [ -n "$wall" ] || exit 0
    cmd_set "$wall"
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: thumb
# -----------------------------------------------------------------------------
cmd_thumb() {
    exec "$BACKEND/thumbnail.sh" "$@"
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: watch
# -----------------------------------------------------------------------------
cmd_watch() {
    exec "$BACKEND/watcher.sh" "$@"
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: search
# -----------------------------------------------------------------------------
cmd_search() {
    exec "$BACKEND/ddg_search.sh" "$@"
}

# -----------------------------------------------------------------------------
# Dispatcher
# -----------------------------------------------------------------------------
case "$CMD" in
    set)    cmd_set "$@" ;;
    boot)   cmd_boot "$@" ;;
    kill)   cmd_kill "$@" ;;
    ensure) cmd_ensure "$@" ;;
    thumb)  cmd_thumb "$@" ;;
    watch)  cmd_watch "$@" ;;
    clean)  cmd_clean "$@" ;;
    search) cmd_search "$@" ;;
    *)
        echo "Usage: $0 {set|boot|kill|ensure|thumb|watch|clean|search} [args...]" >&2
        exit 1
        ;;
esac
