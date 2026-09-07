#!/usr/bin/env bash

# Strict execution environment
set -uo pipefail

# Prevent duplicate lock processes from fighting over ext-session-lock-v1
if pgrep -f 'quickshell.*Lock\.qml' >/dev/null 2>&1; then
    exit 0
fi

# Reset any stale compositor crash lockscreen state before launching
hyprctl dispatch eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1 || true

# Pre-export the active wallpaper path to eliminate async subshell latency in QML
export CURRENT_WALLPAPER="$(head -n 1 "$HOME/.cache/current_wallpaper.txt" 2>/dev/null || true)"

# Export live system telemetry for dynamic lockscreen headers
export SYS_KERNEL="$(uname -r 2>/dev/null || true)"
export SYS_LOAD="$(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || true)"
export SYS_UPTIME="$(awk '{h=int($1/3600); m=int(($1%3600)/60); printf "%dh %02dm", h, m}' /proc/uptime 2>/dev/null || true)"

# Source and initialize quickshell dynamic caching
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "lock"

# Resolve the correct NixOS binary dynamically
QS_BIN=""
if command -v quickshell >/dev/null 2>&1; then
    QS_BIN="quickshell"
elif command -v qs >/dev/null 2>&1; then
    QS_BIN="qs"
else
    exit 1
fi

"$QS_BIN" -p "$HOME/.config/hypr/scripts/quickshell/Lock.qml"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    # In case of an unexpected crash, clear Hyprland lockscreen crash flag so the session is not bricked
    hyprctl dispatch eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1 || true
fi

exit $EXIT_CODE
