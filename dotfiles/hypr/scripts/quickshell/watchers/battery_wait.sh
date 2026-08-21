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
# Run in the background + wait so an external SIGTERM (quickshell teardown,
# reload.sh) can interrupt us immediately: bash defers traps until the
# current FOREGROUND command returns, which left the old foreground
# `timeout 300 grep` surviving up to 300s as an orphan duplicate. Wait on
# the grep PID only — udevadm monitor runs forever and bare `wait` would
# block on it.
timeout 300 grep -m 1 "change" < "$PIPE" > /dev/null &
BLOCK_PID=$!
wait "$BLOCK_PID"

# Anti-spin debounce
sleep 1.5