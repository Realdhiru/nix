#!/usr/bin/env bash
#
# wallpaper_watcher.sh -- background watcher that immediately cleans residue
# and synchronizes cache whenever wallpapers are added, deleted, or moved in ~/Pictures/Wallpapers.
#
set -uo pipefail

SRC="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/quickshell/wallpaper_picker"
THUMB="$CACHE_DIR/thumbs"
COLOR_DIR="$CACHE_DIR/colors_markers"
FLAT_DIR="$CACHE_DIR/flat"
GIF_DIR="$HOME/.cache/converted_gifs"
CURRENT_TXT="$HOME/.cache/current_wallpaper.txt"
THUMB_SCRIPT="$HOME/.config/hypr/scripts/wallpaper_thumbnail.sh"

# Prevent multiple watcher instances
LOCKFILE="$HOME/.cache/wallpaper_watcher.pid"
if [ -f "$LOCKFILE" ]; then
    OLD_PID=$(cat "$LOCKFILE" 2>/dev/null || true)
    if [ -n "$OLD_PID" ] && grep -qa "wallpaper_watcher" "/proc/$OLD_PID/cmdline" 2>/dev/null; then
        exit 0
    fi
fi
echo "$$" > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

cleanup_residue() {
    # 1. Clean broken symlinks and invalid links (pointing to previews or scripts) in flat/
    if [ -d "$FLAT_DIR" ]; then
        while IFS= read -r -d '' link; do
            local target
            target=$(readlink -f "$link" 2>/dev/null || true)
            if [ ! -e "$link" ] || [[ "$target" == *"/previews/"* ]] || [[ "$target" == *"/scripts/"* ]]; then
                local base
                base=$(basename "$link")
                local raw_name="${base#*_}"
                
                rm -f "$THUMB/$base" "$THUMB/$base.jpg" "$THUMB/$raw_name" "$THUMB/$raw_name.jpg" 2>/dev/null || true
                rm -f "$COLOR_DIR/${base}_"* "$COLOR_DIR/${raw_name}_"* 2>/dev/null || true
                rm -f "$GIF_DIR/${base}.mp4" "$GIF_DIR/${raw_name}.mp4" 2>/dev/null || true
                rm -f "$link" 2>/dev/null || true
            fi
        done < <(find "$FLAT_DIR" -type l -print0 2>/dev/null)
    fi

    # 2. Clean orphaned thumbs
    if [ -d "$THUMB" ] && [ -d "$FLAT_DIR" ]; then
        for t in "$THUMB"/*; do
            [ -f "$t" ] || continue
            local t_name
            t_name=$(basename "$t")
            local clean_name="${t_name#*_}"
            local clean_no_jpg="${clean_name%.jpg}"
            local t_no_jpg="${t_name%.jpg}"

            local found=0
            for candidate in "$t_name" "$t_no_jpg" "$clean_name" "$clean_no_jpg"; do
                if [ -e "$FLAT_DIR/$candidate" ]; then
                    found=1
                    break
                fi
            done
            [ "$found" -eq 0 ] && rm -f "$t" 2>/dev/null || true
        done
    fi

    # 3. Clean orphaned color markers
    if [ -d "$COLOR_DIR" ] && [ -d "$FLAT_DIR" ]; then
        for m in "$COLOR_DIR"/*; do
            [ -f "$m" ] || continue
            local m_name
            m_name=$(basename "$m")
            local wall_name="${m_name%_HEX_*}"
            wall_name="${wall_name%_CAT_*}"
            local clean_wall="${wall_name#*_}"
            local clean_no_jpg="${clean_wall%.jpg}"
            local wall_no_jpg="${wall_name%.jpg}"

            local found=0
            for candidate in "$wall_name" "$wall_no_jpg" "$clean_wall" "$clean_no_jpg"; do
                if [ -e "$FLAT_DIR/$candidate" ]; then
                    found=1
                    break
                fi
            done
            [ "$found" -eq 0 ] && rm -f "$m" 2>/dev/null || true
        done
    fi

    # 4. Clean orphaned converted gifs
    if [ -d "$GIF_DIR" ] && [ -d "$FLAT_DIR" ]; then
        for g in "$GIF_DIR"/*.mp4; do
            [ -f "$g" ] || continue
            local g_name
            g_name=$(basename "$g" .mp4)
            local clean_gif="${g_name#*_}"
            local gif_name1="$clean_gif"
            local gif_name2="${clean_gif%.gif}.gif"
            local raw_name1="$g_name"
            local raw_name2="${g_name%.gif}.gif"

            local found=0
            for candidate in "$raw_name1" "$raw_name2" "$gif_name1" "$gif_name2"; do
                if [ -e "$FLAT_DIR/$candidate" ] || [ -f "$SRC/$candidate" ]; then
                    found=1
                    break
                fi
            done
            [ "$found" -eq 0 ] && rm -f "$g" 2>/dev/null || true
        done
    fi

    # 5. Check if currently active wallpaper was deleted or points to previews
    if [ -f "$CURRENT_TXT" ]; then
        local cur_path
        cur_path="$(cat "$CURRENT_TXT" 2>/dev/null || echo "")"
        if [ -z "$cur_path" ] || [ ! -f "$cur_path" ] || [[ "$cur_path" == *"/previews/"* ]] || [[ "$cur_path" == *"/scripts/"* ]]; then
            rm -f "$CURRENT_TXT"
            rm -f "$HOME/.cache/last_wallpaper.txt"
            rm -f "$HOME/.cache/previous_wallpaper.txt"
            rm -rf "$HOME/.cache/awww"/* 2>/dev/null || true
            "$HOME/.config/hypr/scripts/boot_wallpaper.sh" &
        fi
    fi

    # 6. Clean last and previous wallpaper caches if deleted
    for f in "$HOME/.cache/last_wallpaper.txt" "$HOME/.cache/previous_wallpaper.txt"; do
        if [ -f "$f" ]; then
            local p
            p="$(cat "$f" 2>/dev/null || echo "")"
            if [ -z "$p" ] || [ ! -f "$p" ] || [[ "$p" == *"/previews/"* ]]; then
                rm -f "$f"
            fi
        fi
    done
}

# Run initial cleanup and sync on startup
cleanup_residue
if [ -x "$THUMB_SCRIPT" ]; then
    "$THUMB_SCRIPT" &
fi

# Watch ~/Pictures/Wallpapers recursively for any media changes (line-buffered for instant response)
stdbuf -oL inotifywait -m -r -q \
    -e create -e delete -e moved_from -e moved_to -e close_write \
    --exclude "(\.git|previews|scripts|.*\.tmp|.*~)" \
    --format '%w%f' \
    "$SRC" 2>/dev/null | while read -r changed_file; do
    # Debounce: drain any events arriving in rapid succession within 0.5s
    while read -t 0.5 -r next_file; do
        :
    done

    cleanup_residue
    if [ -x "$THUMB_SCRIPT" ]; then
        "$THUMB_SCRIPT" &
    fi
done

