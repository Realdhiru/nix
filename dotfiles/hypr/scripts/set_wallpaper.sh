#!/usr/bin/env bash

WALL="$1"

pkill mpvpaper 2>/dev/null
sleep 0.1

mpvpaper \
-o "no-audio --loop-playlist --hwdec=auto --panscan=1.0" \
'*' \
"$WALL" &

matugen image "$WALL" --config ~/nix/dotfiles/matugen/config.toml -m dark -t expressive --source-color-index 0

touch ~/.config/wezterm/wezterm.lua
