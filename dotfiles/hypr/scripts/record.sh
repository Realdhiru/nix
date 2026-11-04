#!/usr/bin/env bash

# Strict execution environment: Catch undefined variables and pipe failures
set -uo pipefail

TARGET_DIR="$HOME/Videos/Recordings"
DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
REC_STATE_DIR="$DESKTOP_STATE_DIR/recording"
PID_FILE="$REC_STATE_DIR/rec_pid"

mkdir -p "$TARGET_DIR" "$REC_STATE_DIR"

# 1. Lifecycle Check: If active via strict PID tracking, terminate cleanly
if [ -s "$PID_FILE" ]; then
    REC_PID=$(cat "$PID_FILE")
    if kill -0 "$REC_PID" 2>/dev/null; then
        # Send SIGINT to gracefully stop encoding and flush the MP4 footer
        kill -SIGINT "$REC_PID"
        truncate -s 0 "$PID_FILE"
        notify-send -a "Recorder" -t 2000 -u low "Recording Saved"
        exit 0
    else
        # Purge stale PID if the recorder crashed previously
        truncate -s 0 "$PID_FILE"
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

    OUT_FILE="$TARGET_DIR/rec_$(date +%Y%m%d_%H%M%S).mp4"
    # Launch recorder in the background to capture its exact PID
    gpu-screen-recorder \
      -w region \
      -region "$REGION_GEOM" \
      -f 60 \
      -c mp4 \
      -a default_output \
      -q high \
      -tune performance \
      -o "$OUT_FILE" >/dev/null 2>&1 &
    
    REC_PID=$!
    echo "$REC_PID" > "$PID_FILE.tmp" && mv -f "$PID_FILE.tmp" "$PID_FILE"
    notify-send -a "Recorder" -t 1500 "Recording Started" 2>/dev/null || true
    
    # Suspend subshell until the recorder exits (naturally or via SIGINT)
    wait "$REC_PID" 2>/dev/null
    STATUS=$?
    
    # Atomic cleanup: Resets the Quickshell TopBar indicator instantly
    truncate -s 0 "$PID_FILE"
    if [ "$STATUS" -ne 0 ] && [ "$STATUS" -ne 130 ]; then
        notify-send -a "Recorder" -u critical "Recording Failed" 2>/dev/null || true
    fi
) &