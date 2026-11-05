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
GIF_DIR="$CACHE_DIR/gifs"
DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
STATE_WALL_DIR="$DESKTOP_STATE_DIR/wallpaper"
STATE_MODES_DIR="$DESKTOP_STATE_DIR/modes"
CURRENT_TXT="$STATE_WALL_DIR/current_wallpaper.txt"
LAST_TXT="$STATE_WALL_DIR/last_wallpaper.txt"
WP_KILLED_FILE="$STATE_MODES_DIR/wallpaper_killed"
DEFAULT_WALLPAPER="${DEFAULT_WALLPAPER:-}"

mkdir -p "$CACHE_DIR" "$THUMB_DIR" "$COLOR_DIR" "$FLAT_DIR" "$GIF_DIR" "$STATE_WALL_DIR" "$STATE_MODES_DIR"

atomic_write() {
    local target="$1"
    local content="$2"
    local dir
    dir="$(dirname "$target")"
    local tmp="$dir/.$(basename "$target").tmp.$$"
    printf '%s\n' "$content" > "$tmp"
    mv -f "$tmp" "$target"
}

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
            cmd_boot
        fi
    fi
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: kill
# -----------------------------------------------------------------------------
cmd_kill() {
    local state_ctl="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
    mkdir -p "$STATE_WALL_DIR"
    local throttle_lock="$STATE_WALL_DIR/wallpaper_kill_throttle"

    # Throttle rapid keybind spam (protects Intel GPU ring buffer from sub-180ms debounce chattering)
    if [ -f "$throttle_lock" ]; then
        local now
        now=$(date +%s%N)
        local last
        last=$(cat "$throttle_lock" 2>/dev/null || echo 0)
        local diff=$((now - last))
        # 180ms debounce threshold; if diff is negative (clock skew/reboot) ignore stale lock
        if [ "$diff" -ge 0 ] && [ "$diff" -lt 180000000 ]; then
            return 0
        fi
    fi
    date +%s%N > "$throttle_lock" 2>/dev/null || true

    local mode_ctl="$HOME/nix/dotfiles/hypr/scripts/mode_ctl.sh"
    [ -f "$mode_ctl" ] || mode_ctl="$HOME/.config/hypr/scripts/mode_ctl.sh"

    local is_killed="false"
    if [ -s "$STATE_MODES_DIR/modes.json" ]; then
        is_killed=$(jq -r '.active["wallpaper-kill"] // false' "$STATE_MODES_DIR/modes.json" 2>/dev/null || echo "false")
    fi

    if [ "$is_killed" = "true" ]; then
        # TOGGLE BACK ON:
        if bash "$mode_ctl" set wallpaper-kill false; then
            notify-send -a "Wallpaper" -u low "ON"
        else
            notify-send -a "Wallpaper" -u critical "Failed"
            return 1
        fi
        return 0
    fi

    # TOGGLE OFF:
    if ! bash "$mode_ctl" can-enable wallpaper-kill; then
        notify-send -a "Wallpaper" -u critical "Blocked"
        return 0
    fi
    # 1. Preserve current wallpaper before killing
    if [ -s "$CURRENT_TXT" ]; then
        local prev_cur
        prev_cur="$(cat "$CURRENT_TXT" 2>/dev/null || true)"
        if [ -n "$prev_cur" ] && [ -f "$prev_cur" ]; then
            atomic_write "$LAST_TXT" "$prev_cur"
        fi
    fi

    # 2. Engage wallpaper-kill mode via mode_ctl.sh (handles surfaces, rules, and neutral theme)
    if bash "$mode_ctl" set wallpaper-kill true; then
        notify-send -a "Wallpaper" -u low "OFF"
    else
        notify-send -a "Wallpaper" -u critical "Failed"
        return 1
    fi
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
    local mode_ctl="$HOME/nix/dotfiles/hypr/scripts/mode_ctl.sh"
    [ -f "$mode_ctl" ] || mode_ctl="$HOME/.config/hypr/scripts/mode_ctl.sh"
    if bash "$mode_ctl" is-active wallpaper-kill 2>/dev/null; then
        exit 0
    fi

    local wall=""
    if [ -s "$CURRENT_TXT" ]; then
        local cached
        cached="$(cat "$CURRENT_TXT" 2>/dev/null || true)"
        if [ -n "$cached" ] && [ -f "$cached" ] && [[ "$cached" != *"/previews/"* ]]; then
            wall="$cached"
        fi
    fi

    if [ -z "$wall" ] && [ -s "$LAST_TXT" ]; then
        local last
        last="$(cat "$LAST_TXT" 2>/dev/null || true)"
        if [ -n "$last" ] && [ -f "$last" ]; then
            wall="$last"
        fi
    fi

    if [ -z "$wall" ]; then
        if [ -n "${DEFAULT_WALLPAPER:-}" ] && [ -f "$DEFAULT_WALLPAPER" ]; then
            wall="$DEFAULT_WALLPAPER"
        else
            echo "Error: DEFAULT_WALLPAPER is not configured or does not exist: '${DEFAULT_WALLPAPER:-}'" >&2
            exit 1
        fi
    fi

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
# SUBCOMMAND: fav (toggle favorite status of current wallpaper)
# -----------------------------------------------------------------------------
cmd_fav() {
    local fav_file="${XDG_DATA_HOME:-$HOME/.local/share}/wallpaper_favorites.txt"
    mkdir -p "$(dirname "$fav_file")"
    [ ! -f "$fav_file" ] && touch "$fav_file"

    local target="${1:-}"
    if [ -z "$target" ]; then
        if [ -s "$CURRENT_TXT" ]; then
            target="$(cat "$CURRENT_TXT" 2>/dev/null || true)"
        elif [ -s "$LAST_TXT" ]; then
            target="$(cat "$LAST_TXT" 2>/dev/null || true)"
        fi
    fi

    if [ -z "$target" ] || [ ! -f "$target" ]; then
        notify-send -a "Wallpaper" -u low "No Wallpaper Set"
        return 1
    fi

    local real_target
    real_target="$(readlink -f "$target" 2>/dev/null || echo "$target")"

    if grep -Fxq "$real_target" "$fav_file" 2>/dev/null; then
        local tmp_fav
        tmp_fav="$(mktemp "${fav_file}.XXXXXX")"
        grep -Fxv "$real_target" "$fav_file" > "$tmp_fav" || true
        mv -f "$tmp_fav" "$fav_file"
        notify-send -a "Wallpaper" -u low "Removed from Favorites"
    else
        echo "$real_target" >> "$fav_file"
        notify-send -a "Wallpaper" -u low "Added to Favorites"
    fi
}

cmd_cycle() {
    local cycle_sh="$SCRIPT_DIR/../hypr/scripts/cycle_wallpaper.sh"
    [ -f "$cycle_sh" ] || cycle_sh="$HOME/.config/hypr/scripts/cycle_wallpaper.sh"
    exec "$cycle_sh" "$@"
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
    fav|toggle-fav) cmd_fav "$@" ;;
    cycle)  cmd_cycle "$@" ;;
    next)   cmd_cycle "next" ;;
    prev)   cmd_cycle "prev" ;;
    *)
        echo "Usage: $0 {set|boot|kill|ensure|thumb|watch|clean|search|fav|cycle|next|prev} [args...]" >&2
        exit 1
        ;;
esac
