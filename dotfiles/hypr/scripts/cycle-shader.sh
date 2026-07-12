#!/usr/bin/env bash
set -euo pipefail

SHADER_DIR="$HOME/.config/hypr/shaders"
CONF_FILE="$HOME/.cache/current_shader.conf"

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

CURRENT_INDEX=-1
for i in "${!SHADERS[@]}"; do
    if [[ "${SHADERS[$i]}" == "$CURRENT_SHADER" ]]; then
        CURRENT_INDEX=$i
        break
    fi
done

NEXT_INDEX=$((CURRENT_INDEX + 1))

if (( NEXT_INDEX >= ${#SHADERS[@]} )); then
    NEXT_SHADER="[[EMPTY]]"
else
    NEXT_SHADER="${SHADERS[$NEXT_INDEX]}"
fi

# Live-apply immediately — instant, no reload required for this to be visible.
hyprctl keyword decoration:screen_shader "$NEXT_SHADER" >/dev/null

# Persist into the sourced config file so this survives every future
# Hyprland reload automatically (from any trigger — BatteryPopup,
# MonitorPopup, a manual reload, anything). No restore hook needed
# anywhere else in the codebase; Hyprland re-reads this on every reload
# the same way it re-reads appearance.conf or any other sourced file.
echo "decoration:screen_shader = $NEXT_SHADER" > "$CONF_FILE"