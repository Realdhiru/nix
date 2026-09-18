#!/usr/bin/env bash
# On-demand webcam loopback controller for Sonix 3277:0022 firmware quirk.
# Turns the camera on ONLY when needed for a meeting/browser call,
# and shuts it off immediately so the LED light stays off.

# Hardware probe: Only needed if the buggy Sonix webcam is present
SONIX_DEV="/dev/v4l/by-id/usb-Sonix_Technology_Co.__Ltd._USB2.0_FHD_UVC_WebCam-video-index0"
if [ ! -e "$SONIX_DEV" ] && ! (command -v lsusb >/dev/null && lsusb -d 3277:0022 >/dev/null 2>&1); then
  echo "[webcam] Notice: Sonix 3277:0022 webcam not detected. Your system does not need this workaround."
  notify-send -a "Webcam" -i camera-web "Webcam" "Standard webcam detected. No workaround needed."
  exit 0
fi

action="${1:-toggle}"

case "$action" in
  on|start)
    systemctl --user start camera-loopback
    notify-send -a "Webcam" -i camera-web "Webcam Activated" "Virtual Webcam (/dev/video10) is active."
    echo "[webcam] Camera loopback started. Device: /dev/video10"
    ;;
  off|stop)
    systemctl --user stop camera-loopback 2>/dev/null
    pkill -f "camera-loopback.sh" 2>/dev/null
    pkill -f "ffmpeg.*video10" 2>/dev/null
    notify-send -a "Webcam" -i camera-web "Webcam Deactivated" "Camera sensor and light powered off."
    echo "[webcam] Camera loopback stopped. Hardware is off."
    ;;
  status)
    if systemctl --user is-active --quiet camera-loopback 2>/dev/null || pgrep -f "ffmpeg.*video10" >/dev/null; then
      echo "ACTIVE (Camera sensor is ON)"
    else
      echo "OFF (Camera sensor and LED are OFF)"
    fi
    ;;
  toggle|*)
    if systemctl --user is-active --quiet camera-loopback 2>/dev/null || pgrep -f "ffmpeg.*video10" >/dev/null; then
      "$0" off
    else
      "$0" on
    fi
    ;;
esac
