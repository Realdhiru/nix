#!/usr/bin/env bash
set -euo pipefail

SHADER_DIR="$HOME/.config/hypr/shaders"
STATE_FILE="$HOME/.cache/current_shader"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use native bash globbing for safe array population
shopt -s nullglob
SHADERS=("$SHADER_DIR"/*.frag)
shopt -u nullglob

# Abort cleanly if no shaders exist
if [[ ${#SHADERS[@]} -eq 0 ]]; then
    exit 0
fi

# Use exact JSON extraction to prevent regex brittleness
CURRENT_SHADER=$(hyprctl -j getoption decoration:screen_shader | jq -r '.str')

# Restore from cache if Hyprland dropped the shader (e.g., after a reload).
# Shared with setPowerProfile() in BatteryPopup.qml — see restore-shader.sh.
if [[ "$CURRENT_SHADER" == "[[EMPTY]]" || "$CURRENT_SHADER" == "null" || -z "$CURRENT_SHADER" ]]; then
    "$SCRIPT_DIR/restore-shader.sh"
    CURRENT_SHADER=$(hyprctl -j getoption decoration:screen_shader | jq -r '.str')

    if [[ "$CURRENT_SHADER" != "[[EMPTY]]" && "$CURRENT_SHADER" != "null" && -n "$CURRENT_SHADER" ]]; then
        exit 0
    fi
    CURRENT_SHADER="[[EMPTY]]"
fi

CURRENT_INDEX=-1

for i in "${!SHADERS[@]}"; do
    if [[ "${SHADERS[$i]}" == "$CURRENT_SHADER" ]]; then
        CURRENT_INDEX=$i
        break
    fi
done

NEXT_INDEX=$((CURRENT_INDEX + 1))

if (( NEXT_INDEX >= ${#SHADERS[@]} )); then
    hyprctl keyword decoration:screen_shader "[[EMPTY]]" >/dev/null
    echo "[[EMPTY]]" > "$STATE_FILE"
else
    NEXT_SHADER="${SHADERS[$NEXT_INDEX]}"
    hyprctl keyword decoration:screen_shader "$NEXT_SHADER" >/dev/null
    echo "$NEXT_SHADER" > "$STATE_FILE"
fi