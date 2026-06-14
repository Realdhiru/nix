#!/usr/bin/env bash

mkdir -p ~/.cache/quickshell/wallpaper_thumbs

for file in ~/Pictures/Wallpapers/*
do
    name=$(basename "$file")

    if [[ "$file" =~ \.(jpg|jpeg|png)$ ]]
    then
        magick "$file" \
            -thumbnail x300 \
            ~/.cache/quickshell/wallpaper_thumbs/"$name"
    else
        ffmpeg \
            -y \
            -i "$file" \
            -vf scale=-1:300 \
            -frames:v 1 \
            ~/.cache/quickshell/wallpaper_thumbs/"$name".jpg \
            >/dev/null 2>&1
    fi
done