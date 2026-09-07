#!/usr/bin/env bash
#
# colors_wait.sh -- event-driven watcher for qs_colors.json
# Blocks until ~/.cache/matugen/qs_colors.json changes (inotify),
# with a 300s timeout failsafe, then exits so MatugenColors re-reads instantly.

TARGET="$HOME/.cache/matugen/qs_colors.json"

trap "exit 0" EXIT INT TERM

if command -v inotifywait >/dev/null 2>&1; then
    mkdir -p "$(dirname "$TARGET")"
    [ -f "$TARGET" ] || touch "$TARGET"
    timeout 300 inotifywait -q -e close_write -e moved_to "$TARGET" >/dev/null 2>&1
else
    sleep 300
fi
