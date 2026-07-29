#!/usr/bin/env bash
# Keeps a bluetoothctl agent registered for the whole session.
#
# Confirmed root cause this fixes: this repo has ZERO references to
# `bluetoothctl agent`/`default-agent` anywhere -- no pairing agent has
# ever been registered on this system. Without one, BlueZ has nowhere to
# send a pairing confirmation request, so it silently times out no matter
# what the UI does.
#
# A one-shot `bluetoothctl agent on` does NOT persist -- the agent is tied
# to that process's D-Bus connection, which closes (de-registering the
# agent) the instant the fire-and-forget CLI call exits. This keeps a
# single bluetoothctl session open indefinitely (stdin never hits EOF,
# because of the trailing `sleep infinity`), so the registration survives.
#
# NoInputNoOutput auto-accepts "Just Works" pairing, which covers the vast
# majority of consumer audio/HID devices (headphones, earbuds, mice,
# keyboards) with zero prompt needed. It does NOT surface a visual
# confirmation for devices that require displaying/confirming a numeric
# passkey -- if you hit one of those, say so and a real interactive
# Yes/No confirmation (wired through the existing notification
# action-button system) can be built as a follow-up; that's a materially
# bigger, separate piece of work and this script intentionally doesn't
# guess at it.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "network"
PID_FILE="$QS_RUN_DIR/bt_agent_pid"

# Idempotent: if an instance is already alive, do nothing.
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    exit 0
fi

{
    echo "agent NoInputNoOutput"
    echo "default-agent"
    sleep infinity
} | bluetoothctl > /dev/null 2>&1 &

echo $! > "$PID_FILE"