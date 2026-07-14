#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_kb_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

# Destroys both the grep hook and the hidden socat socket binder
trap 'rm -f "$PIPE"; pkill -P $$ 2>/dev/null; exit 0' EXIT INT TERM

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    LC_ALL=C socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock 2>/dev/null | grep --line-buffered "activelayout>>" > "$PIPE" &
else
    sleep 10 > "$PIPE" &
fi

# Failsafe timeout matching audio_wait.sh/battery_wait.sh/network_wait.sh —
# same unbounded-read leak risk as the others if layout switches are rare.
timeout 10 bash -c 'read -r _ < "$1"' _ "$PIPE"
sleep 0.05