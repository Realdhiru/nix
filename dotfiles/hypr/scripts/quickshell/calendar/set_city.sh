#!/usr/bin/env bash
set -euo pipefail

SECRET_FILE="$HOME/nix/dotfiles/secrets/openweather.json"
if [ ! -f "$SECRET_FILE" ]; then
    exit 1
fi

CITY_ID="$1"
if [ -z "$CITY_ID" ]; then
    exit 1
fi

# Update city_id in the JSON file
TMP_FILE=$(mktemp)
jq --arg id "$CITY_ID" '.city_id = $id' "$SECRET_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$SECRET_FILE"

# Trigger a weather refresh
~/.config/hypr/scripts/quickshell/calendar/weather.sh --getdata
