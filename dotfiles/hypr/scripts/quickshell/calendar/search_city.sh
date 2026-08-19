#!/usr/bin/env bash
set -euo pipefail

SECRET_FILE="$HOME/nix/dotfiles/secrets/openweather.json"
if [ ! -f "$SECRET_FILE" ]; then
    echo "[]"
    exit 0
fi

KEY=$(jq -r '.api_key // empty' "$SECRET_FILE")
if [ -z "$KEY" ]; then
    echo "[]"
    exit 0
fi

QUERY="$1"
if [ -z "$QUERY" ]; then
    echo "[]"
    exit 0
fi

# Fetch from OpenWeatherMap find API
RAW=$(curl -s "http://api.openweathermap.org/data/2.5/find?q=$(echo -n "$QUERY" | jq -sRr @uri)&appid=${KEY}")

# Format as JSON array
echo "$RAW" | jq -c '[.list[] | {id: .id, name: .name, country: .sys.country}]'
