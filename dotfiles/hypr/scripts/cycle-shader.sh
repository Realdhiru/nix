#!/usr/bin/env bash

SHADER_DIR="$HOME/.config/hypr/shaders"
STATE_FILE="$HOME/.cache/current_shader"

mapfile -t SHADERS < <(
    find "$SHADER_DIR" -maxdepth 1 -name "*.frag" | sort
)

# Add "none" as the last state
TOTAL=$(( ${#SHADERS[@]} + 1 ))

CURRENT=0

if [[ -f "$STATE_FILE" ]]; then
    CURRENT=$(cat "$STATE_FILE")
fi

# If shader is currently disabled (e.g. after reload),
# re-enable the current shader instead of advancing.
if hyprctl getoption decoration:screen_shader | grep -q 'str: ""'; then
    NEXT=$CURRENT
else
    NEXT=$(( (CURRENT + 1) % TOTAL ))
fi

if [[ "$NEXT" -eq "${#SHADERS[@]}" ]]; then
    hyprctl keyword decoration:screen_shader ""
else
    hyprctl keyword decoration:screen_shader "${SHADERS[$NEXT]}"
fi

echo "$NEXT" > "$STATE_FILE"