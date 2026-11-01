#!/usr/bin/env bash
set -euo pipefail

# Supports either setup_weather.sh "lat,lon,name,country" or legacy setup_weather.sh "dummy_key" "city_id"
ARG1="${1:-}"
ARG2="${2:-}"

TARGET="${ARG2:-$ARG1}"

if [ -n "$TARGET" ]; then
    "$(dirname "${BASH_SOURCE[0]}")/set_city.sh" "$TARGET"
fi

# Close the setup popup
~/.config/hypr/scripts/qs_manager.sh close 2>/dev/null || true
