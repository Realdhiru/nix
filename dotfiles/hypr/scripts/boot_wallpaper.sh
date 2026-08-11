#!/usr/bin/env bash
#
# boot_wallpaper.sh -- single, race-free wallpaper path at login.
#
# Replaces the previous two competing startup entries (set_wallpaper.sh +
# standalone ensure_awww.sh), which started awww-daemon twice in parallel
# at login and panicked one instance (systemd-coredump, unwrap_failed in
# main). This script is the ONLY login-time entry point:
#   current_wallpaper.txt (if present and existing) -> set_wallpaper.sh
#   otherwise -> most recently modified wallpaper in ~/Pictures/Wallpapers
# set_wallpaper.sh internally ensures the daemon, so it starts exactly once.

set -uo pipefail

WALL=""

if [ -f "$HOME/.cache/current_wallpaper.txt" ]; then
    CACHED="$(cat "$HOME/.cache/current_wallpaper.txt")"
    if [ -n "$CACHED" ] && [ -f "$CACHED" ]; then
        WALL="$CACHED"
    fi
fi

if [ -z "$WALL" ]; then
    WALL="$(find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
        -iname '*.gif' -o -iname '*.mp4' -o -iname '*.mkv' -o \
        -iname '*.mov' -o -iname '*.webm' \) -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | head -n 1 | cut -d' ' -f2-)"
fi

[ -n "$WALL" ] || exit 0

exec "$HOME/.config/hypr/scripts/set_wallpaper.sh" "$WALL"
