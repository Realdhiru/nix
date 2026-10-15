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
        # TOGGLE BACK ON: Delegate to cmd_set so wallpaper renders on screen BEFORE transparency restores
        local target=""
        if [ -s "$LAST_TXT" ]; then
            target="$(cat "$LAST_TXT" 2>/dev/null || true)"
        elif [ -f "$HOME/.cache/last_wallpaper.txt" ]; then
            target="$(cat "$HOME/.cache/last_wallpaper.txt" 2>/dev/null || true)"
        fi
        if [ -n "$target" ] && [ -f "$target" ]; then
            cmd_set "$target" "fade" "0.25" "120"
        else
            rm -f "$HOME/.cache/wallpaper_killed"
            cmd_boot
            if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
                hyprctl eval "hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } }, animations = { enabled = true } })" >/dev/null 2>&1 || true
                hyprctl reload >/dev/null 2>&1 || true
            fi
        fi
        [ -x "$state_ctl" ] && bash "$state_ctl" set modes.wallpaperKilled false 2>/dev/null || true
        notify-send -a "Wallpaper" -u low "ON"
        return 0
    fi

    # TOGGLE OFF:
    # 1. Immediately enforce 100% solid opacity across windows & popups (frame-0 instant feedback)
    echo "1" > "$HOME/.cache/wallpaper_killed"
    [ -x "$state_ctl" ] && bash "$state_ctl" set modes.wallpaperKilled true 2>/dev/null || true
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } }, animations = { enabled = true } })" >/dev/null 2>&1 || true
        hyprctl eval "hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })" >/dev/null 2>&1 || true
    fi
    notify-send -a "Wallpaper" -u low "OFF"

    # 2. Preserve wallpaper target file caches
    if [ -s "$CURRENT_TXT" ]; then
        cp -f "$CURRENT_TXT" "$LAST_TXT" 2>/dev/null || true
    elif [ -f "$HOME/.cache/current_wallpaper.txt" ]; then
        cp -f "$HOME/.cache/current_wallpaper.txt" "$LAST_TXT" 2>/dev/null || true
    fi
    rm -f "$CURRENT_TXT"
    touch "$CURRENT_TXT"

    # 3. Clean daemon teardown (fast check without artificial 100ms sleep)
    "$BACKEND/ensure_awww.sh" --stop 2>/dev/null || true
    local pids
    pids=$(pidof .mpvpaper-wrapped 2>/dev/null || true)
    if [ -n "$pids" ]; then
        for pid in $pids; do kill -15 "$pid" 2>/dev/null || true; done
        for i in {1..5}; do pidof .mpvpaper-wrapped >/dev/null 2>&1 || break; sleep 0.01; done
        pids=$(pidof .mpvpaper-wrapped 2>/dev/null || true)
        if [ -n "$pids" ]; then
            for pid in $pids; do kill -9 "$pid" 2>/dev/null || true; done
        fi
    fi
    rm -f /tmp/mpv-paper-socket "$HOME/.cache/mpvpaper.pid"

    # 4. Decoupled neutral theme trigger
    THEME_ENGINE="${THEME_ENGINE:-$HOME/.config/wallust/generate.sh}"
    [ ! -x "$THEME_ENGINE" ] && THEME_ENGINE="$HOME/nix/dotfiles/wallust/generate.sh"
    if [ -x "$THEME_ENGINE" ]; then
        "$THEME_ENGINE" --neutral >/dev/null 2>&1 &
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
    *)
        echo "Usage: $0 {set|boot|kill|ensure|thumb|watch|clean|search|fav} [args...]" >&2
        exit 1
        ;;
esac
