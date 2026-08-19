#!/usr/bin/env bash
set -euo pipefail

API_KEY="$1"
CITY_ID="$2"

SECRET_DIR="$HOME/nix/dotfiles/secrets"
SECRET_FILE="$SECRET_DIR/openweather.json"

mkdir -p "$SECRET_DIR"
jq -n --arg api "$API_KEY" --arg city "$CITY_ID" '{api_key: $api, city_id: $city}' > "$SECRET_FILE"

# Trigger a weather refresh
~/.config/hypr/scripts/quickshell/calendar/weather.sh --getdata

# Close the setup popup
~/.config/hypr/scripts/qs_manager.sh close
