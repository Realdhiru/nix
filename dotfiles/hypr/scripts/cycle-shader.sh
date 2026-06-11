#!/usr/bin/env bash

SHADER_DIR="$HOME/.config/hypr/shaders"
STATE_FILE="$HOME/.cache/current_shader"

mapfile -t SHADERS < <(
    find "$SHADER_DIR" -maxdepth 1 -name "*.frag" | sort
)

CURRENT_SHADER=$(hyprctl getoption decoration:screen_shader | sed -n 's/^str: //p')

# Hyprland reset the shader after reload
if [[ "$CURRENT_SHADER" == "[[EMPTY]]" ]]; then
    if [[ -f "$STATE_FILE" ]]; then
        LAST_SHADER=$(cat "$STATE_FILE")

        if [[ "$LAST_SHADER" != "[[EMPTY]]" ]]; then
            hyprctl keyword decoration:screen_shader "$LAST_SHADER"
            exit 0
        fi
    fi
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
    hyprctl keyword decoration:screen_shader ""
    echo "[[EMPTY]]" > "$STATE_FILE"
else
    hyprctl keyword decoration:screen_shader "${SHADERS[$NEXT_INDEX]}"
    echo "${SHADERS[$NEXT_INDEX]}" > "$STATE_FILE"
fi