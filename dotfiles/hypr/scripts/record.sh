#!/usr/bin/env bash

TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"

OUTPUT_FILE="$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4"

if pgrep -x "gpu-screen-reco" > /dev/null; then
    killall -SIGINT gpu-screen-recorder
    exit 0
fi

# FIXED: Use the guaranteed hardware mapping alias for your active PipeWire server
AUDIO_SINK="default_output"

# FIXED: Replaced nvidia 'vaapi' fallback syntax to ensure crisp h264/h265 raw capture on your Iris Xe GPU
gpu-screen-recorder -w screen -f 60 -c mp4 -a "$AUDIO_SINK" -q ultra -o "$OUTPUT_FILE" &