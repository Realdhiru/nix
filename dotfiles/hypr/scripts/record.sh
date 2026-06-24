#!/usr/bin/env bash

TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"

# 1. If an active recording is running, stop it cleanly
if pgrep -x "gpu-screen-recorder" > /dev/null; then
    pkill -SIGINT -x "gpu-screen-recorder"
    notify-send -t 2000 "GPU Recorder" "Recording saved to $TARGET_DIR"
    exit 0
fi

# 2. If slurp is already active, it means the user pressed the hotkey to CANCEL selection
if pgrep -x "slurp" > /dev/null; then
    pkill -x "slurp"
    notify-send -t 1500 "GPU Recorder" "Selection canceled"
    exit 0
fi

# 3. No active session or selection -> launch selection tool
REGION_GEOM=$(slurp)

# Clean exit if slurp returns empty (e.g. user pressed Escape)
if [ -z "$REGION_GEOM" ]; then
    exit 0
fi

AUDIO_SINK="default_output"
OUTPUT_FILE="$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4"

notify-send -t 2000 "GPU Recorder" "Region capture started at 120 FPS..."

# 4. Launch encoder engine
gpu-screen-recorder -w region -region "$REGION_GEOM" -f 120 -c mp4 -a "$AUDIO_SINK" -q ultra -o "$OUTPUT_FILE" &