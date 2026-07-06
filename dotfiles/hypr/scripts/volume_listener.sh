#!/usr/bin/env bash

# Safe Singleton File Locking
# Enforces a single instance to prevent duplicate OSD triggers if the UI reloads
exec 200>"${XDG_RUNTIME_DIR:-/tmp}/qs_volume_listener.lock"
if ! flock -n 200; then
    exit 0
fi

# Signal binding trap to drop child consumers (pactl) instantly on thread closure
cleanup() { pkill -P $$ 2>/dev/null; }
trap cleanup EXIT SIGTERM SIGINT

# Helper functions to get current state safely
get_sink() { pactl get-default-sink 2>/dev/null; }
get_vol() { pamixer --get-volume 2>/dev/null; }
get_mute() { pamixer --get-mute 2>/dev/null; }

listen_audio_events() {
    # 1. Initialize state
    local last_sink=$(get_sink)
    local last_vol=$(get_vol)
    local last_mute=$(get_mute)

    # 2. Loop through events
    pactl subscribe 2>/dev/null | grep --line-buffered "Event 'change' on sink" | while read -r _; do
        
        local current_sink=$(get_sink)
        local current_vol=$(get_vol)
        local current_mute=$(get_mute)

        # CHECK 1: Did the Output Device change? (e.g. Headphones connected)
        if [[ "$current_sink" != "$last_sink" ]]; then
            # The device changed. We do NOT want a popup for this.
            # Just update our tracking variables to the new device's levels.
            last_sink="$current_sink"
            last_vol="$current_vol"
            last_mute="$current_mute"
            continue
        fi

        # CHECK 2: Did the Volume/Mute actually change on the SAME device?
        if [[ "$current_vol" != "$last_vol" ]] || [[ "$current_mute" != "$last_mute" ]]; then
            
            # Trigger OSD (without changing volume)
            swayosd-client --output-volume 0 2>/dev/null

            # Update tracking
            last_vol="$current_vol"
            last_mute="$current_mute"
        fi
    done
}

# Resurrection loop: Keeps the daemon alive if PipeWire/PulseAudio crashes or restarts
while true; do
    listen_audio_events
    sleep 1
done