#!/usr/bin/env bash
# Camera loopback feeder for Sonix Technology USB webcam.
# Feeds the stable native 1080p@5fps YUYV stream directly into /dev/video10
# using zero-CPU pass-through (-codec copy).
# Never force -video_size or -framerate on the input device to avoid triggering the Sonix firmware crash.

DEV="/dev/v4l/by-id/usb-Sonix_Technology_Co.__Ltd._USB2.0_FHD_UVC_WebCam-video-index0"
LOOPBACK="/dev/video10"

# Ensure loopback device exists
until [ -e "$LOOPBACK" ]; do
  sleep 1
done

while true; do
  # Wait for physical camera to be enumerated
  until [ -e "$DEV" ]; do
    sleep 2
  done

  # Settle time for USB bus enumeration
  sleep 2

  echo "[camera-loopback] Starting pass-through feed to $LOOPBACK..."
  ffmpeg -y -hide_banner -loglevel error \
    -f v4l2 -i "$DEV" \
    -codec copy \
    -f v4l2 "$LOOPBACK"

  echo "[camera-loopback] Stream ended or disconnected, restarting in 3 seconds..."
  sleep 3
done
