#!/usr/bin/env bash

# Define target video output storage path
TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"

OUTPUT_FILE="$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4"

# Handle active record instance toggle routing
if pgrep -x "gpu-screen-reco" > /dev/null; then
    # Gracefully terminate session to finalize file indexing
    killall -SIGINT gpu-screen-recorder
    exit 0
fi

# Detect default pulse audio monitor sink map
AUDIO_SINK="$(pactl get-default-sink).monitor"

# Start optimized GPU capturing process
# Adjust encoder mapping: 'nvenc' for NVIDIA, 'vaapi' for AMD/Intel hardware
gpu-screen-recorder -w screen -f 60 -c mp4 -a "$AUDIO_SINK" -q ultra -o "$OUTPUT_FILE" &