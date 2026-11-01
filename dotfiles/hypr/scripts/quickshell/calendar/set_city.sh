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
if [ -z "$lat" ] || [ -z "$lon" ]; then
    exit 1
fi

cat <<EOF > "$CONFIG_FILE"
{
  "name": "${name:-Unknown}",
  "country": "${country:-}",
  "latitude": ${lat},
  "longitude": ${lon},
  "unit": "metric"
}
EOF

# Trigger a weather refresh
~/.config/hypr/scripts/quickshell/calendar/weather.sh --getdata >/dev/null 2>&1 &
