#!/usr/bin/env bash

# Safe Singleton File Locking
exec 200>"${XDG_RUNTIME_DIR:-/tmp}/qs_volume_listener.lock"
if ! flock -n 200; then
    exit 0
fi

cleanup() { pkill -P $$ 2>/dev/null; }
trap cleanup EXIT SIGTERM SIGINT

get_sink() { pactl get-default-sink 2>/dev/null; }
get_vol() { pamixer --get-volume 2>/dev/null; }
get_mute() { pamixer --get-mute 2>/dev/null; }

# The new direct IPC bridge
QS_IPC="quickshell ipc -p ~/.config/hypr/scripts/quickshell/Shell.qml call main showOSD"

listen_audio_events() {
    local last_sink=$(get_sink)
    local last_vol=$(get_vol)
    local last_mute=$(get_mute)

    pactl subscribe 2>/dev/null | grep --line-buffered "Event 'change' on sink" | while read -r _; do
        local current_sink=$(get_sink)
        local current_vol=$(get_vol)
        local current_mute=$(get_mute)

        # Output device changed (e.g., plugged in headphones). Update tracking, no OSD.
        if [[ "$current_sink" != "$last_sink" ]]; then
            last_sink="$current_sink"
            last_vol="$current_vol"
            last_mute="$current_mute"
            continue
        fi

        # Volume or Mute state actually changed. Fire the OSD.
        if [[ "$current_vol" != "$last_vol" ]] || [[ "$current_mute" != "$last_mute" ]]; then
            if [[ "$current_mute" == "true" ]]; then
                bash -c "$QS_IPC \"volume\" \"Muted\"" &
            else
                bash -c "$QS_IPC \"volume\" \"$current_vol\"" &
            fi

            last_vol="$current_vol"
            last_mute="$current_mute"
        fi
    done
}

while true; do
    listen_audio_events
    sleep 1
done