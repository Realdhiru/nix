#!/usr/bin/env bash

LOCK_FILE="/tmp/gpu_recorder.lock"
TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"

# 1. ATOMIC CHECK: If lock exists, kill the recorder immediately and clean up
if [ -f "$LOCK_FILE" ]; then
    pkill -f -SIGINT "gpu-screen-recorder"
    rm -f "$LOCK_FILE"
    notify-send -t 2000 "GPU Recorder" "Recording saved to ~/Videos/Recordings/"
    exit 0
fi

# 2. SLOW PATH: No lock found, meaning we want to start a new session
REGION_GEOM=$(slurp)

# Exit cleanly if selection is canceled
if [ -z "$REGION_GEOM" ]; then
    notify-send -t 1500 "GPU Recorder" "Recording canceled"
    exit 0
fi

# Create the atomic lock file IMMEDIATELY after a successful region choice
touch "$LOCK_FILE"

AUDIO_SINK="default_output"
notify-send -t 2000 "GPU Recorder" "Region capture started at 120 FPS..."

# Launch encoder engine
gpu-screen-recorder -w region -region "$REGION_GEOM" -f 120 -c mp4 -a "$AUDIO_SINK" -q ultra -o "$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4" &