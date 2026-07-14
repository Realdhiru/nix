#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_battery_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

# pkill -P $$ guarantees every child of this script dies when this script
# exits, matching network_wait.sh/kb_wait.sh/bt_wait.sh's proven pattern.
# The previous single-PID kill left the script capable of hanging forever
# mid-grep with no cleanup path if udevadm (or a descendant of it) kept
# the FIFO's write end open after MONITOR_PID itself was gone.
trap 'rm -f "$PIPE"; pkill -P $$ 2>/dev/null; exit 0' EXIT INT TERM

# Run udevadm isolated and capture its exact PID
LC_ALL=C udevadm monitor --subsystem-match=power_supply 2>/dev/null > "$PIPE" &
MONITOR_PID=$!

# Blocks until udevadm catches a change, OR 10 seconds pass (failsafe).
# Either way, when this line finishes, the trap fires and cleans up perfectly.
timeout 10 grep -m 1 "change" < "$PIPE" > /dev/null