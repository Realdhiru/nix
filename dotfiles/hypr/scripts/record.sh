#!/usr/bin/env bash

TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"

if pgrep -x "gpu-screen-recorder" > /dev/null; then
    pkill -SIGINT -x "gpu-screen-recorder"
    notify-send -t 2000 "GPU Recorder" "Recording saved to $TARGET_DIR"
    exit 0
fi

if pgrep -x "slurp" > /dev/null; then
    pkill -x "slurp"
    notify-send -t 1500 "GPU Recorder" "Selection canceled"
    exit 0
fi

REGION_GEOM=$(slurp -f "%w_x_%h+%x+%y" | sed 's/_x_/x/g')

if [ -z "$REGION_GEOM" ]; then
    exit 0
fi

notify-send -t 2000 "GPU Recorder" "Region capture started at 60 FPS..."

# FIXED: Dropped frame rate to 60 FPS to half hardware encoding overhead
gpu-screen-recorder \
  -w region \
  -region "$REGION_GEOM" \
  -f 60 \
  -c mp4 \
  -a default_output \
  -q high \
  -tune performance \
  -o "$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4" &