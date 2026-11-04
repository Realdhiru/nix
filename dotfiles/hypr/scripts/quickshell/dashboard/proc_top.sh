#!/usr/bin/env bash
# Fast, event/demand-driven process and broadcast sampler for QuickShell Dashboard.
# Executes only on-demand while the Dashboard widget is active.

set -euo pipefail

# 1. Audio broadcast state flag
if [ -f "${XDG_RUNTIME_DIR:-/run/user/$UID}/pw_broadcast_active" ]; then
    echo "__BC_ON__"
else
    echo "__BC_OFF__"
fi

# 2. Top 7 processes by CPU usage
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | awk 'NR>1 && NR<=8 {
    sub(/^\./, "", $2)
    sub(/-wrapped$/, "", $2)
    printf "%s\t%s\t%s\t%s\n", $1, $2, $3, $4
}'
