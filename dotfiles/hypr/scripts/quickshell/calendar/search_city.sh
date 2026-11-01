#!/usr/bin/env bash
set -euo pipefail

QUERY="${1:-}"
if [ -z "$QUERY" ]; then
    echo "[]"
    exit 0
fi

encoded_query=$(jq -rn --arg q "$QUERY" '$q|@uri')
raw=$(curl -sf -m 6 "https://geocoding-api.open-meteo.com/v1/search?name=${encoded_query}&count=10&language=en&format=json" 2>/dev/null || echo "{}")
echo "$raw" | jq -c '[.results[]? | { id: "\(.latitude),\(.longitude),\(.name),\(.country_code // "")", name: .name, country: (.country // .country_code // "") }]' 2>/dev/null || echo "[]"
