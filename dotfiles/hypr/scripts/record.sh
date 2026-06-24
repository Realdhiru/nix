#!/usr/bin/env bash

TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"

# 1. FIXED: Removed -x flag so pkill correctly signals the wrapped binary path
if pgrep -f "gpu-screen-recorder" > /dev/null; then
    pkill -SIGINT -f "gpu-screen-recorder"
    notify-send -t 2000 "GPU Recorder" "Recording saved to $TARGET_DIR"
    exit 0
fi

# 2. If slurp is running, cancel the selection
if pgrep -x "slurp" > /dev/null; then
    pkill -x "slurp"
    notify-send -t 1500 "GPU Recorder" "Selection canceled"
    exit 0
fi

# 3. Handle region definition and encoding in a separate thread context
(
    REGION_GEOM=$(slurp -f "%w_x_%h+%x+%y" | sed 's/_x_/x/g')
    
    if [ -z "$REGION_GEOM" ]; then
        exit 0
    fi

    notify-send -t 2000 "GPU Recorder" "Region capture started at 60 FPS..."

    gpu-screen-recorder \
      -w region \
      -region "$REGION_GEOM" \
      -f 60 \
      -c mp4 \
      -a default_output \
      -q high \
      -tune performance \
      -o "$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4"
) &