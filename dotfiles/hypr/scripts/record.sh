#!/usr/bin/env bash

TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"

# 1. Check if the core recorder binary is already active
if pgrep -x "gpu-screen-recorder" > /dev/null; then
    # Send the interrupt signal gracefully to flush video indexing to disk
    pkill -X -SIGINT "gpu-screen-recorder"
    notify-send -t 2000 "GPU Recorder" "Recording saved to $TARGET_DIR"
    exit 0
fi

# 2. No active session found -> launch region selection
REGION_GEOM=$(slurp)

# Clean exit if user hits Escape or clicks away
if [ -z "$REGION_GEOM" ]; then
    notify-send -t 1500 "GPU Recorder" "Recording canceled"
    exit 0
fi

AUDIO_SINK="default_output"
OUTPUT_FILE="$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4"

notify-send -t 2000 "GPU Recorder" "Region capture started at 120 FPS..."

# 3. Launch with exact binary name execution mapping
gpu-screen-recorder -w region -region "$REGION_GEOM" -f 120 -c mp4 -a "$AUDIO_SINK" -q ultra -o "$OUTPUT_FILE" &

# 4. Small sleep delay ensures pgrep catches the background process on the next hotkey press
sleep 0.3