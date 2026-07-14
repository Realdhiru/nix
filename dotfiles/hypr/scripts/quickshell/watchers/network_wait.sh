#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_network_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

# pkill -P $$ guarantees every child of this script (nmcli monitor, and any
# reader stage) dies when this script exits, matching kb_wait.sh/bt_wait.sh's
# proven pattern. The previous single-PID kill left the script capable of
# hanging forever mid-grep with no cleanup path, which is what caused
# dozens of stuck instances to accumulate over uptime.
trap 'rm -f "$PIPE"; pkill -P $$ 2>/dev/null; exit 0' EXIT INT TERM

# Run nmcli completely isolated and capture its exact PID
LC_ALL=C nmcli monitor 2>/dev/null > "$PIPE" &
MONITOR_PID=$!

# Flushes the immediate startup status dump from nmcli to prevent instant-trigger loops
timeout 0.5 cat "$PIPE" > /dev/null 2>&1

# Grep blocks until it reads the first match from the FIFO, OR 10 seconds
# pass (failsafe) — matching audio_wait.sh/battery_wait.sh. Without this
# timeout, a quiet network (no connect/disconnect events for a while) left
# this grep blocked forever; since bash defers a trap until its current
# foreground command returns, an external SIGTERM from Quickshell tearing
# the process down couldn't interrupt it either, so the script (and its
# nmcli child) became a permanent orphan — confirmed via pgrep showing 15
# stuck instances that survived a full `pkill -f quickshell`.
timeout 10 grep -m 1 -iwE "connected|disconnected|enabled|disabled|activated|deactivated|available|unavailable" < "$PIPE" > /dev/null

# Anti-spin debounce to protect C-states
sleep 1.5