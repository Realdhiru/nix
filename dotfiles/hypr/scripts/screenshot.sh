#!/usr/bin/env bash
set -uo pipefail

TARGET_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$TARGET_DIR"

MODE="${1:-area}"
FILE="$TARGET_DIR/Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

case "$MODE" in
    screen|output|full)
        grim "$FILE"
        ;;
    ocr)
        if ! command -v tesseract >/dev/null 2>&1; then
            notify-send -a "OCR" -u critical "Tesseract Missing" 2>/dev/null || true
            exit 1
        fi
        geom="$(slurp 2>/dev/null)" || exit 0
        [ -z "$geom" ] && exit 0
        text="$(grim -g "$geom" -t ppm - 2>/dev/null \
            | OMP_THREAD_LIMIT=1 tesseract stdin stdout -l eng --oem 1 --psm 6 -c preserve_interword_spaces=1 2>/dev/null \
            | tr -d '\f')"
        trimmed="${text#"${text%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        if [ -n "$trimmed" ]; then
            printf '%s' "$text" | wl-copy -n --type "text/plain;charset=utf-8"
            notify-send -a "OCR" "Copied to clipboard" 2>/dev/null || true
        else
            notify-send -a "OCR" "No text found" 2>/dev/null || true
        fi
        exit 0
        ;;
    freeze)
        grimblast --freeze save area "$FILE" >/dev/null 2>&1
        ;;
    area|*)
        geom="$(slurp 2>/dev/null)" || exit 0
        [ -z "$geom" ] && exit 0
        grim -g "$geom" "$FILE"
        ;;
esac

if [ -f "$FILE" ]; then
    wl-copy --type image/png < "$FILE" 2>/dev/null || true
    notify-send -a "Screenshot" -i "$FILE" "Captured to clipboard" 2>/dev/null || true
else
    notify-send -a "Screenshot" -u critical "Capture Failed" 2>/dev/null || true
fi

