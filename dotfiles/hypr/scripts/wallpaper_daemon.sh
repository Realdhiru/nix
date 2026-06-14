#!/usr/bin/env bash

CACHE="$HOME/.cache/current_wallpaper"

while true
do
    if [ -f "$CACHE" ]; then
        ~/.config/hypr/scripts/set_wallpaper.sh "$(cat "$CACHE")"
    fi

    sleep infinity
done