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
    freeze)
        grimblast --freeze save area "$FILE" >/dev/null 2>&1
        ;;
    area|*)
        grimblast save area "$FILE" >/dev/null 2>&1
        ;;
esac

if [ -f "$FILE" ]; then
    wl-copy --type image/png < "$FILE" 2>/dev/null || true
fi
