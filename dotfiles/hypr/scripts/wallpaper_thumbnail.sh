#!/usr/bin/env bash

SRC="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/quickshell/wallpaper_picker"
THUMB="$CACHE_DIR/thumbs"
COLOR_DIR="$CACHE_DIR/colors_markers"

mkdir -p "$THUMB" "$COLOR_DIR"

export THUMB COLOR_DIR
find "$SRC" -maxdepth 1 -type f -print0 | xargs -0 -P $(nproc) -I {} bash -c '
    file="{}"
    name=$(basename "$file")
    
    target="$THUMB/$name"
    if [[ "${file,,}" =~ \.(mp4|mkv|mov|webm)$ ]]; then
        target="$THUMB/$name.jpg"
        [ ! -f "$target" ] && ffmpeg -hide_banner -loglevel error -y -ss 00:00:01 -i "$file" -frames:v 1 -vf "scale=400:-1" "$target"
    else
        [ ! -f "$target" ] && magick "$file[0]" -thumbnail 400x400^ -gravity center -extent 400x400 "$target"
    fi

    marker=$(find "$COLOR_DIR" -name "${name}_HEX_*" -print -quit)
    if [ -z "$marker" ] && [ -f "$target" ]; then
        hex=$(magick "$target" -resize 1x1 -format "%[hex:p{0,0}]" info: 2>/dev/null | cut -c 1-6)
        [ -n "$hex" ] && touch "$COLOR_DIR/${name}_HEX_${hex}"
    fi
'
