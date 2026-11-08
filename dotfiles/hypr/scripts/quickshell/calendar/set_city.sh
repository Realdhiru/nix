#!/usr/bin/env bash
set -euo pipefail

CITY_ARG="${1:-}"
if [ -z "$CITY_ARG" ]; then
    exit 1
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/calendar"
CONFIG_FILE="$STATE_DIR/weather_config.json"
mkdir -p "$STATE_DIR"

IFS=',' read -r lat lon name country <<< "$CITY_ARG"
if [[ ! "$lat" =~ ^-?[0-9]+([.][0-9]+)?$ || ! "$lon" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || \
   ! awk -v lat="$lat" -v lon="$lon" 'BEGIN { exit !(lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) }'; then
    exit 1
fi

tmp_file="$STATE_DIR/.weather_config.json.$$"
jq -n \
    --arg name "${name:-Unknown}" \
    --arg country "${country:-}" \
    --argjson latitude "$lat" \
    --argjson longitude "$lon" \
    '{name:$name, country:$country, latitude:$latitude, longitude:$longitude, unit:"metric"}' \
    > "$tmp_file"
mv -f "$tmp_file" "$CONFIG_FILE"

# Trigger a weather refresh
~/.config/hypr/scripts/quickshell/calendar/weather.sh --getdata >/dev/null 2>&1 &
