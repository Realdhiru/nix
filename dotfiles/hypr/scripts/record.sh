#!/usr/bin/env bash

# Strict execution environment: Catch undefined variables and pipe failures
set -uo pipefail

TARGET_DIR="$HOME/Videos/Recordings"
REC_CACHE_DIR="$HOME/.cache/quickshell/recording"
PID_FILE="$REC_CACHE_DIR/rec_pid"

mkdir -p "$TARGET_DIR" "$REC_CACHE_DIR"

# 1. Lifecycle Check: If active via strict PID tracking, terminate cleanly
if [ -f "$PID_FILE" ]; then
    REC_PID=$(cat "$PID_FILE")
    if kill -0 "$REC_PID" 2>/dev/null; then
        # Send SIGINT to gracefully stop encoding and flush the MP4 footer
        kill -SIGINT "$REC_PID"
        notify-send -a "System" -t 2500 -u normal "GPU Recorder" "Recording successfully saved to $TARGET_DIR"
        exit 0
    else
        # Purge stale PID file if the recorder crashed previously
        rm -f "$PID_FILE"
    fi
fi

# Fallback: Catch dangling slurp instances if the user is stuck in selection mode
if pgrep -x "slurp" > /dev/null; then
    pkill -x "slurp"
    exit 0
fi

# 2. Run region selection and encode asynchronously
(
    # Slurp natively supports the exact WxH+X+Y format; sed is unnecessary
    REGION_GEOM=$(slurp -f "%wx%h+%x+%y" 2>/dev/null)
    
    if [ -z "$REGION_GEOM" ]; then
        exit 0
    fi

    # Launch recorder in the background to capture its exact PID
    gpu-screen-recorder \
      -w region \
      -region "$REGION_GEOM" \
      -f 60 \
      -c mp4 \
      -a default_output \
      -q high \
      -tune performance \
      -o "$TARGET_DIR/rec_$(date +%Y%m%d_%H%M).mp4" >/dev/null 2>&1 &
    
    REC_PID=$!
    echo "$REC_PID" > "$PID_FILE"
    
    # Suspend subshell until the recorder exits (naturally or via SIGINT)
    wait "$REC_PID" 2>/dev/null
    
    # Atomic cleanup: Resets the Quickshell TopBar indicator instantly
    rm -f "$PID_FILE"
) &