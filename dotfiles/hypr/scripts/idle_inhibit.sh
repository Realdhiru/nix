#!/usr/bin/env bash
set -uo pipefail

STATE_FILE="$HOME/.cache/idle_inhibit.pid"

inhibitor_active() {
    systemd-inhibit --list 2>/dev/null | grep -q "idle-inhibit-toggle"
}

stop_inhibitor() {
    if [[ -f "$STATE_FILE" ]]; then
        kill -- -"$(cat "$STATE_FILE")" 2>/dev/null
    fi
    pkill -x systemd-inhibit 2>/dev/null
    rm -f "$STATE_FILE"
}

if inhibitor_active; then
    stop_inhibitor
    notify-send -a "System" -r 9991 -t 1200 -u low -i "appointment-missed" "Coffee mode OFF"
else
    stop_inhibitor
    setsid systemd-inhibit --what=idle --who=idle-inhibit-toggle --why=manual --mode=block sleep infinity &
    echo $! > "$STATE_FILE"
    notify-send -a "System" -r 9991 -t 0 -u low -i "appointment-soon" "Coffee mode ON"
fi