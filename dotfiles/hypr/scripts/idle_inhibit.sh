#!/usr/bin/env bash
set -uo pipefail

STATE_FILE="$HOME/.cache/idle_inhibit.pid"

if [[ -f "$STATE_FILE" ]] && kill -0 "$(cat "$STATE_FILE")" 2>/dev/null; then
    kill -- -"$(cat "$STATE_FILE")" 2>/dev/null
    rm -f "$STATE_FILE"
    hyprctl notify 5 1500 "rgb(ffffff)" "Idle inhibit OFF — idle actions restored"
else
    rm -f "$STATE_FILE"
    setsid systemd-inhibit --what=idle --who=idle-inhibit-toggle --why=manual --mode=block sleep infinity &
    echo $! > "$STATE_FILE"
    hyprctl notify 5 1500 "rgb(70c870)" "Idle inhibit ON — screen/lock/suspend paused"
fi