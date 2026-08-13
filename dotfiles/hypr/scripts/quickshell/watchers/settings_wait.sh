#!/usr/bin/env bash
#
# settings_wait.sh -- event-driven replacement for Main.qml's 3s settings
# polling. Blocks until ~/.config/hypr/settings.json changes (inotify), with
# the same 300s failsafe as the other watchers, then exits so the caller
# (Main.qml settingsReader Process) re-reads the file and re-blocks.

TARGET="$HOME/.config/hypr/settings.json"

trap 'exit 0' EXIT INT TERM

if [ -f "$TARGET" ] && command -v inotifywait >/dev/null 2>&1; then
    timeout 300 inotifywait -q -e close_write -e moved_to "$TARGET" >/dev/null 2>&1
else
    sleep 300
fi