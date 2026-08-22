#!/usr/bin/env bash
#
# update_wait.sh -- event-driven replacement for the old 2-second
# update_pending polling. Blocks until something changes inside the updater
# cache dir (file created/deleted/rewritten), with the same 300s failsafe as
# settings_wait.sh, then exits so the caller (TopBar.qml updateReader
# Process) re-reads the state and re-blocks.

source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "updater"

trap 'exit 0' EXIT INT TERM

if command -v inotifywait >/dev/null 2>&1; then
    timeout 300 inotifywait -q -e close_write -e create -e delete -e moved_to -e moved_from "$QS_CACHE_UPDATER" >/dev/null 2>&1
else
    sleep 300
fi
