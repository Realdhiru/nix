#!/usr/bin/env bash

SRC="$HOME/Pictures/Wallpapers"
THUMB="$HOME/.cache/quickshell/wallpaper_picker/thumbs"

mkdir -p "$THUMB"

rm -f "$THUMB"/*

find "$SRC" -maxdepth 1 -type f | while read -r file
do
    name=$(basename "$file")

    case "${file,,}" in
        *.jpg|*.jpeg|*.png|*.webp)
            magick "$file" \
                -thumbnail x420 \
                "$THUMB/$name"
            ;;

        *.gif)
            magick "$file[0]" \
                -thumbnail x420 \
                "$THUMB/$name"
            ;;

        *.mp4|*.mkv|*.mov|*.webm)
            ffmpeg \
                -y \
                -ss 00:00:01 \
                -i "$file" \
                -frames:v 1 \
                "$THUMB/$name.jpg" \
                >/dev/null 2>&1
            ;;
    esac
done