#!/usr/bin/env bash

SHADER_DIR="$HOME/.config/hypr/shaders"
STATE_FILE="$HOME/.cache/current_shader"

mapfile -t SHADERS < <(
    find "$SHADER_DIR" -maxdepth 1 -name "*.frag" | sort
)

TOTAL=$(( ${#SHADERS[@]} + 1 ))

CURRENT=0
[[ -f "$STATE_FILE" ]] && CURRENT=$(cat "$STATE_FILE")

# Shader got reset (e.g. hyprctl reload)
if hyprctl getoption decoration:screen_shader | grep -q 'str: ""'; then
    NEXT="$CURRENT"
else
    NEXT=$(( (CURRENT + 1) % TOTAL ))
fi

if [[ "$NEXT" -eq "${#SHADERS[@]}" ]]; then
    hyprctl keyword decoration:screen_shader ""
else
    hyprctl keyword decoration:screen_shader "${SHADERS[$NEXT]}"
fi

# Save currently applied state
echo "$NEXT" > "$STATE_FILE"