#!/usr/bin/env bash

TARGET_DIR="$HOME/Videos/Recordings"
mkdir -p "$TARGET_DIR"

PID_FILE="/tmp/gpu_record.pid"
OUTPUT_FILE="$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4"

# 1. If PID file exists, read it and terminate that exact process
if [ -f "$PID_FILE" ]; then
    REC_PID=$(cat "$PID_FILE")
    rm -f "$PID_FILE"
    
    # Check if process is actually alive before killing
    if kill -0 "$REC_PID" 2>/dev/null; then
        kill -SIGINT "$REC_PID"
        notify-send -t 2000 "GPU Recorder" "Recording saved to ~/Videos/Recordings/"
        exit 0
    fi
fi

# 2. Get region geometry interactively via slurp
REGION_GEOM=$(slurp)

# Exit cleanly if selection is canceled
if [ -z "$REGION_GEOM" ]; then
    notify-send -t 1500 "GPU Recorder" "Recording canceled"
    exit 0
fi

AUDIO_SINK="default_output"
notify-send -t 2000 "GPU Recorder" "Region capture started at 120 FPS..."

# 3. Launch encoder and capture its background PID instantly
gpu-screen-recorder -w region -region "$REGION_GEOM" -f 120 -c mp4 -a "$AUDIO_SINK" -q ultra -o "$OUTPUT_FILE" &
echo $! > "$PID_FILE"