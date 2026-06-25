#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_audio_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

trap 'rm -f "$PIPE"; kill $MONITOR_PID 2>/dev/null; exit 0' EXIT INT TERM

# Run pactl isolated and capture its exact PID to prevent PipeWire connection exhaustion
LC_ALL=C pactl subscribe 2>/dev/null > "$PIPE" &
MONITOR_PID=$!

# FIXED: Case-insensitive broad event tracking with a 10-second fail-safe timeout
if ! timeout 10 grep -m 1 -iE "sink|server|change|remove|new" < "$PIPE" > /dev/null; then
    # Fallback delay prevents QuickShell from rapid-fire thwacking your CPU if pactl hangs
    sleep 2.0
fi