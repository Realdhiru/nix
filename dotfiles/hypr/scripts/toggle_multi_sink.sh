#!/usr/bin/env bash
# Fast wrapper redirecting to standalone pw-broadcast tool
if command -v pw-broadcast >/dev/null 2>&1; then
    exec pw-broadcast toggle "$@"
elif [ -x "$HOME/Projects/pipewire-multi-sink/bin/pw-broadcast" ]; then
    exec "$HOME/Projects/pipewire-multi-sink/bin/pw-broadcast" toggle "$@"
else
    notify-send -a "Audio" -u critical "Broadcast Missing"
    exit 1
fi
