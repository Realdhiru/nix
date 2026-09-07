#!/usr/bin/env bash

# Strict execution environment: Ensure failures inside the script are caught,
# but do not use `set -e` globally to prevent a single bad image from killing the batch.
set -uo pipefail

SRC="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/quickshell/wallpaper_picker"
THUMB="$CACHE_DIR/thumbs"
COLOR_DIR="$CACHE_DIR/colors_markers"
FLAT_DIR="$CACHE_DIR/flat"

# Ensure target directories exist before processing
GIF_DIR="$HOME/.cache/converted_gifs"
mkdir -p "$THUMB" "$COLOR_DIR" "$FLAT_DIR" "$GIF_DIR"

# 1. Clean broken symlinks in flat/ and their associated cache
if [ -d "$FLAT_DIR" ]; then
    while IFS= read -r -d '' link; do
        base=$(basename "$link")
        raw_name="${base#*_}"
        
        rm -f "$THUMB/$base" "$THUMB/$base.jpg" "$THUMB/$raw_name" "$THUMB/$raw_name.jpg" 2>/dev/null || true
        rm -f "$COLOR_DIR/${base}_HEX_"* "$COLOR_DIR/${raw_name}_HEX_"* 2>/dev/null || true
        rm -f "$GIF_DIR/${base}.mp4" "$GIF_DIR/${raw_name}.mp4" 2>/dev/null || true
        rm -f "$link" 2>/dev/null || true
    done < <(find "$FLAT_DIR" -xtype l -print0 2>/dev/null)
fi

# 2. Sweep thumbs directory for orphaned thumbnails
if [ -d "$THUMB" ] && [ -d "$FLAT_DIR" ]; then
    for t in "$THUMB"/*; do
        [ -f "$t" ] || continue
        t_name=$(basename "$t")
        clean_name="${t_name#*_}"
        clean_no_jpg="${clean_name%.jpg}"
        t_no_jpg="${t_name%.jpg}"

        found=0
        for candidate in "$t_name" "$t_no_jpg" "$clean_name" "$clean_no_jpg"; do
            if [ -e "$FLAT_DIR/$candidate" ]; then
                found=1
                break
            fi
        done
        [ "$found" -eq 0 ] && rm -f "$t" 2>/dev/null || true
    done
fi

# 3. Sweep color markers for orphaned markers
if [ -d "$COLOR_DIR" ] && [ -d "$FLAT_DIR" ]; then
    for m in "$COLOR_DIR"/*; do
        [ -f "$m" ] || continue
        m_name=$(basename "$m")
        wall_name="${m_name%_HEX_*}"
        clean_wall="${wall_name#*_}"
        clean_no_jpg="${clean_wall%.jpg}"
        wall_no_jpg="${wall_name%.jpg}"

        found=0
        for candidate in "$wall_name" "$wall_no_jpg" "$clean_wall" "$clean_no_jpg"; do
            if [ -e "$FLAT_DIR/$candidate" ]; then
                found=1
                break
            fi
        done
        [ "$found" -eq 0 ] && rm -f "$m" 2>/dev/null || true
    done
fi

# 4. Sweep converted_gifs for orphaned mp4s
if [ -d "$GIF_DIR" ] && [ -d "$FLAT_DIR" ]; then
    for g in "$GIF_DIR"/*.mp4; do
        [ -f "$g" ] || continue
        g_name=$(basename "$g" .mp4)
        clean_gif="${g_name#*_}"
        gif_name1="$clean_gif"
        gif_name2="${clean_gif%.gif}.gif"
        raw_name1="$g_name"
        raw_name2="${g_name%.gif}.gif"

        found=0
        for candidate in "$raw_name1" "$raw_name2" "$gif_name1" "$gif_name2"; do
            if [ -e "$FLAT_DIR/$candidate" ] || [ -f "$SRC/$candidate" ]; then
                found=1
                break
            fi
        done
        [ "$found" -eq 0 ] && rm -f "$g" 2>/dev/null || true
    done
fi

# Export the variables so they are accessible by the xargs subshells
export THUMB COLOR_DIR FLAT_DIR GIF_DIR

# Define the processing logic as an exported function.
process_wallpaper() {
    local file="$1"
    local raw_name
    raw_name=$(basename "$file")
    local hash
    hash=$(md5sum <<< "$file" | cut -d' ' -f1)
    local name="${hash}_${raw_name}"

    ln -sf "$file" "$FLAT_DIR/$name"

    local target="$THUMB/$name"
    local ext="${file##*.}"
    ext="${ext,,}" # lowercase extension

    # Video processing block
    if [[ "$ext" =~ ^(mp4|mkv|mov|webm)$ ]]; then
        target="$THUMB/$name.jpg"
        if [ ! -f "$target" ]; then
            # Safe ffmpeg extraction: 1 frame at 1s mark, scaling width to 400, auto-height
            ffmpeg -hide_banner -loglevel error -y -ss 00:00:01 -i "$file" -frames:v 1 -vf "scale=400:-1" "$target"
        fi
    else
        # Image processing block
        if [ ! -f "$target" ]; then
            # Inject memory-bound scaling constraint (-define jpeg:size) before loading the file
            # This drastically reduces RAM usage and I/O bottlenecks for 4K/8K images.
            magick -define jpeg:size=800x800 "$file[0]" -strip -thumbnail 400x400^ -gravity center -extent 400x400 "$target"
        fi
    fi

    # Dominant color extraction block
    # Check if a hex marker already exists for this specific file
    local marker
    marker=$(find "$COLOR_DIR" -name "${name}_HEX_*" -print -quit)

    if [ -z "$marker" ] && [ -f "$target" ]; then
        local hex
        # Extract average color by scaling to 1x1 pixel.
        # Extract exactly 6 characters to prevent carriage return pollution
        hex=$(magick "$target" -resize 1x1 -format "%[hex:p{0,0}]" info: 2>/dev/null | cut -c 1-6)

        # Only touch the marker file if the hex string is perfectly 6 characters long
        if [ -n "$hex" ] && [ "${#hex}" -eq 6 ]; then
            touch "$COLOR_DIR/${name}_HEX_${hex}"
        fi
    fi
}

export -f process_wallpaper

# Determine safe thread count (leave 1 thread free if possible to prevent UI locking)
CORES=$(nproc)
THREADS=$(( CORES > 2 ? CORES - 1 : 1 ))

# Execute the pipeline. Skip hidden paths and process only valid media files.
find "$SRC" -not -path '*/.*' -type f \(     -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o     -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o     -iname '*.webm' \) -print0 | xargs -0 -P "$THREADS" -I {} bash -c 'process_wallpaper "$@"' _ {}
