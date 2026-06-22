#!/usr/bin/env bash

TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"

OUTPUT_FILE="$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4"

# FIXED: Added -f flag to match the full command line argument layout
if pgrep -f "gpu-screen-recorder" > /dev/null; then
    pkill -f -SIGINT "gpu-screen-recorder"
    exit 0
fi

AUDIO_SINK="default_output"

gpu-screen-recorder -w screen -f 60 -c mp4 -a "$AUDIO_SINK" -q ultra -o "$OUTPUT_FILE" &