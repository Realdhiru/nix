#!/usr/bin/env bash
# Toggle 180° rotation on the focused monitor and persist it in monitor intent.

set -euo pipefail

hyprctl() { timeout 3 env hyprctl "$@"; }

STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}/monitors"
INTENT_FILE="$STATE_DIR/intent.json"
LOCK_FILE="$INTENT_FILE.lock"
TMP_FILE="$INTENT_FILE.tmp"

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1 || ! command -v flock >/dev/null 2>&1; then
    notify-send -a "Display" -u critical "Display Tools Missing" 2>/dev/null || true
    exit 1
fi

MONITOR=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty')
MONITORS_JSON=$(hyprctl monitors -j)
[ -n "$MONITOR" ] || MONITOR=$(printf '%s' "$MONITORS_JSON" | jq -r '.[0].name // empty')

if [ -z "$MONITOR" ]; then
    notify-send -a "Display" -u critical "No Monitor Found" 2>/dev/null || true
    exit 1
fi

MON_INFO=$(printf '%s' "$MONITORS_JSON" | jq -r --arg m "$MONITOR" '
    .[] | select(.name == $m) |
    [.description // "", .scale // 1, .transform // 0, .width // 0, .height // 0, .refreshRate // 60] | @tsv
')
IFS=$'\t' read -r DESCRIPTION SCALE CUR WIDTH HEIGHT REFRESH <<< "$MON_INFO"
DESCRIPTION="${DESCRIPTION:-}"
SCALE="${SCALE:-1}"
CUR="${CUR:-0}"
WIDTH="${WIDTH:-0}"
HEIGHT="${HEIGHT:-0}"
REFRESH="${REFRESH:-60}"

TARGET_ARG="${1:-toggle}"
case "$TARGET_ARG" in
    0|normal) NEW=0 ;;
    2|180|inverted) NEW=2 ;;
    *)
        if [ "$CUR" = "2" ]; then NEW=0; else NEW=2; fi
        ;;
esac

if [ -n "$DESCRIPTION" ]; then KEY="desc:$DESCRIPTION"; else KEY="$MONITOR"; fi
MODE="${WIDTH}x${HEIGHT}@${REFRESH%.*}"
mkdir -p "$STATE_DIR"

(
    flock -w 10 9 || exit 1
    if [ ! -s "$INTENT_FILE" ]; then
        printf '%s\n' '{"layout":"extend","displays":{}}' > "$INTENT_FILE"
    fi
    jq --arg key "$KEY" \
       --arg name "$MONITOR" \
       --arg description "$DESCRIPTION" \
       --arg mode "$MODE" \
       --argjson scale "$SCALE" \
       --argjson transform "$NEW" \
       '.layout = (.layout // "extend")
        | .displays = (.displays // {})
        | .displays[$key] = ((.displays[$key] // {mode: $mode, scale: $scale})
          + {name: $name, description: $description, transform: $transform})' \
       "$INTENT_FILE" > "$TMP_FILE"
    mv -f "$TMP_FILE" "$INTENT_FILE"
) 9>"$LOCK_FILE"

if ! hyprctl eval "hl.monitor({output='${MONITOR}',transform=${NEW}})" >/dev/null; then
    notify-send -a "Display" -u critical "Rotation Failed" 2>/dev/null || true
    exit 1
fi

if [ "$NEW" = "2" ]; then
    notify-send -a "Display" -u low -i video-display "Inverted 180°" 2>/dev/null || true
else
    notify-send -a "Display" -u low -i video-display "Standard" 2>/dev/null || true
fi
