#!/usr/bin/env bash

# Strict execution environment: Ensure failures inside the script are caught,
# but do not use `set -e` globally to prevent a single bad image from killing the batch.
set -uo pipefail

SRC="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/quickshell/wallpaper_picker"
THUMB="$CACHE_DIR/thumbs"
COLOR_DIR="$CACHE_DIR/colors_markers"

# Ensure target directories exist before processing
mkdir -p "$THUMB" "$COLOR_DIR"

# Export the variables so they are accessible by the xargs subshells
export THUMB COLOR_DIR

# Define the processing logic as an exported function.
process_wallpaper() {
    local file="$1"
    local name
    name=$(basename "$file")

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

# Execute the pipeline. Using -print0 and -0 safely handles filenames with spaces/newlines.
find "$SRC" -maxdepth 1 -type f -print0 | xargs -0 -P "$THREADS" -I {} bash -c 'process_wallpaper "$@"' _ {}