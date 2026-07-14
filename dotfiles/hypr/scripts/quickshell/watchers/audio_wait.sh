#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_audio_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

# pkill -P $$ guarantees every child of this script dies when this script
# exits, matching network_wait.sh/kb_wait.sh/bt_wait.sh's proven pattern.
# The previous single-PID kill left the script capable of hanging forever
# mid-grep with no cleanup path if pactl (or a descendant of it) kept the
# FIFO's write end open after MONITOR_PID itself was gone.
trap 'rm -f "$PIPE"; pkill -P $$ 2>/dev/null; exit 0' EXIT INT TERM

# Run pactl isolated and capture its exact PID to prevent PipeWire connection exhaustion
LC_ALL=C pactl subscribe 2>/dev/null > "$PIPE" &
MONITOR_PID=$!

# FIXED: Case-insensitive broad event tracking with a 10-second fail-safe timeout
if ! timeout 10 grep -m 1 -iE "sink|server|change|remove|new" < "$PIPE" > /dev/null; then
    # Fallback delay prevents QuickShell from rapid-fire thwacking your CPU if pactl hangs
    sleep 2.0
fi

# Unconditional throttle prevents UI from thrashing the CPU during rapid scroll-wheel volume changes
sleep 0.5