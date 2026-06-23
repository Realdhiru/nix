#!/usr/bin/env bash

TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"

OUTPUT_FILE="$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4"

# Handle active record instance toggle routing
if pgrep -f "gpu-screen-recorder" > /dev/null; then
    pkill -f -SIGINT "gpu-screen-recorder"
    notify-send -t 2000 "GPU Recorder" "Recording saved to ~/Videos/Recordings/"
    exit 0
fi

# Get region geometry interactively via slurp before starting the encoder
REGION_GEOM=$(slurp)

# Exit cleanly if selection is canceled (Escape / Right-click)
if [ -z "$REGION_GEOM" ]; then
    notify-send -t 1500 "GPU Recorder" "Recording canceled"
    exit 0
fi

AUDIO_SINK="default_output"

notify-send -t 2000 "GPU Recorder" "Region capture started at 120 FPS..."

# Core optimized hardware engine call
gpu-screen-recorder -w region -region "$REGION_GEOM" -f 120 -c mp4 -a "$AUDIO_SINK" -q ultra -o "$OUTPUT_FILE" &