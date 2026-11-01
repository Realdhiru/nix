#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# CACHING & INITIALIZATION
# -----------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "weather"

export LC_ALL=C

# Paths
cache_dir="$QS_CACHE_WEATHER"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"

# -----------------------------------------------------------------------------
# LOCATION CONFIGURATION (KEYLESS OPEN-METEO INTEGRATION)
# -----------------------------------------------------------------------------
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/calendar"
CONFIG_FILE="${STATE_DIR}/weather_config.json"

if [ -f "$CONFIG_FILE" ]; then
    LAT=$(jq -r '.latitude // 28.6667' "$CONFIG_FILE")
    LON=$(jq -r '.longitude // 77.4333' "$CONFIG_FILE")
    UNIT=$(jq -r '.unit // "metric"' "$CONFIG_FILE")
else
    LAT="28.6667"
    LON="77.4333"
    UNIT="metric"
fi

case "$UNIT" in
    "imperial") UNIT_SYM="°F"; UNIT_PARAMS="temperature_unit=fahrenheit&wind_speed_unit=mph" ;;
    "standard") UNIT_SYM="K"; UNIT_PARAMS="temperature_unit=celsius&wind_speed_unit=kmh" ;;
    *) UNIT_SYM="°C"; UNIT_PARAMS="temperature_unit=celsius&wind_speed_unit=kmh" ;;
esac

mkdir -p "${cache_dir}"

get_data() {
    local url="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,precipitation_probability_max,wind_speed_10m_max&timezone=auto&${UNIT_PARAMS}"
    local raw_api
    raw_api=$(curl -sf -m 8 "$url" || echo "")

    if [ -z "$raw_api" ] || ! echo "$raw_api" | jq -e '.current' >/dev/null 2>&1; then
        if [ ! -f "$json_file" ]; then
            echo '{ "timezone": "0", "current_temp": "--", "current_icon": "", "current_hex": "#bac2de", "forecast": [] }' > "$json_file"
        fi
        return
    fi

    echo "$raw_api" | jq '
      def wmo_icon(code):
        if code == 0 then ""
        elif code <= 3 then ""
        elif code == 45 or code == 48 then "󰖑"
        elif (code >= 51 and code <= 67) or (code >= 80 and code <= 82) then "󰖗"
        elif (code >= 71 and code <= 77) or (code >= 85 and code <= 86) then ""
        elif code >= 95 then ""
        else "" end;

      def wmo_hex(code):
        if code == 0 then "#f9e2af"
        elif code <= 3 then "#bac2de"
        elif code == 45 or code == 48 then "#84afdb"
        elif (code >= 51 and code <= 67) or (code >= 80 and code <= 82) then "#74c7ec"
        elif (code >= 71 and code <= 77) or (code >= 85 and code <= 86) then "#cdd6f4"
        elif code >= 95 then "#f9e2af"
        else "#cdd6f4" end;

      def wmo_desc(code):
        if code == 0 then "Clear Sky"
        elif code == 1 then "Mainly Clear"
        elif code == 2 then "Partly Cloudy"
        elif code == 3 then "Overcast"
        elif code == 45 or code == 48 then "Fog"
        elif code >= 51 and code <= 55 then "Drizzle"
        elif code >= 61 and code <= 65 then "Rain"
        elif code == 66 or code == 67 then "Freezing Rain"
        elif code >= 71 and code <= 77 then "Snow"
        elif code >= 80 and code <= 82 then "Rain Showers"
        elif code >= 85 and code <= 86 then "Snow Showers"
        elif code >= 95 then "Thunderstorm"
        else "Partly Cloudy" end;

      {
        timezone: (.utc_offset_seconds | tostring),
        current_temp: (.current.temperature_2m | tostring),
        current_icon: wmo_icon(.current.weather_code),
        current_hex: wmo_hex(.current.weather_code),
        forecast: [
          range(0; 5) as $i |
          {
            id: ($i | tostring),
            day: (.daily.time[$i] | strptime("%Y-%m-%d") | strftime("%a")),
            day_full: (.daily.time[$i] | strptime("%Y-%m-%d") | strftime("%A")),
            date: (.daily.time[$i] | strptime("%Y-%m-%d") | strftime("%d %b")),
            max: (.daily.temperature_2m_max[$i] | tostring),
            min: (.daily.temperature_2m_min[$i] | tostring),
            feels_like: (.daily.apparent_temperature_max[$i] | tostring),
            wind: (.daily.wind_speed_10m_max[$i] | round | tostring),
            humidity: (.current.relative_humidity_2m | round | tostring),
            pop: ((.daily.precipitation_probability_max[$i] // 0) | round | tostring),
            icon: wmo_icon(.daily.weather_code[$i]),
            hex: wmo_hex(.daily.weather_code[$i]),
            desc: wmo_desc(.daily.weather_code[$i]),
            hourly: [
              range(0; 8) as $h |
              ($i * 24 + $h * 3) as $idx |
              {
                time: (.hourly.time[$idx] | split("T")[1]),
                temp: (.hourly.temperature_2m[$idx] | tostring),
                icon: wmo_icon(.hourly.weather_code[$idx]),
                hex: wmo_hex(.hourly.weather_code[$idx])
              }
            ]
          }
        ]
      }
    ' > "$json_file"
}

# -----------------------------------------------------------------------------
# CLI INTERFACE
# -----------------------------------------------------------------------------
action="${1:---getdata}"

if [[ "$action" == "--getdata" || "$action" == "--json" ]]; then
    CACHE_LIMIT=900
    if [ -f "$json_file" ]; then
        last_update=$(stat -c %Y "$json_file" 2>/dev/null || echo "0")
        current_time=$(date +%s)
        diff=$((current_time - last_update))
        if [ $diff -gt $CACHE_LIMIT ]; then
            touch "$json_file"
            get_data
        fi
        cat "$json_file"
    else
        get_data
        cat "$json_file"
    fi
elif [[ "$action" == "--view-listener" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    tail -F "$view_file"
elif [[ "$action" == "--nav" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    current=$(cat "$view_file")
    direction="${2:-next}"
    max_idx=4
    if [[ "$direction" == "next" ]]; then
        if [ "$current" -lt "$max_idx" ]; then
            new=$((current + 1))
            echo "$new" > "$view_file"
        fi
    elif [[ "$direction" == "prev" ]]; then
        if [ "$current" -gt 0 ]; then
            new=$((current - 1))
            echo "$new" > "$view_file"
        fi
    fi
elif [[ "$action" == "--icon" ]]; then
    cat "$json_file" | jq -r '.forecast[0].icon // empty'
elif [[ "$action" == "--temp" ]]; then
    t=$(cat "$json_file" | jq -r '.forecast[0].max // empty')
    echo "${t}${UNIT_SYM}"
elif [[ "$action" == "--hex" ]]; then
    cat "$json_file" | jq -r '.forecast[0].hex // empty'
elif [[ "$action" == "--current-icon" ]]; then
    icon=$(cat "$json_file" | jq -r '.current_icon // empty' 2>/dev/null || echo "")
    if [[ -z "$icon" || "$icon" == "null" ]]; then
        get_data
        icon=$(cat "$json_file" | jq -r '.current_icon // ""')
    fi
    echo "$icon"
elif [[ "$action" == "--current-temp" ]]; then
    t=$(cat "$json_file" | jq -r '.current_temp // empty' 2>/dev/null || echo "")
    if [[ -z "$t" || "$t" == "null" ]]; then
        get_data
        t=$(cat "$json_file" | jq -r '.current_temp // "--"')
    fi
    echo "${t}${UNIT_SYM}"
elif [[ "$action" == "--current-hex" ]]; then
    hex=$(cat "$json_file" | jq -r '.current_hex // empty' 2>/dev/null || echo "")
    if [[ -z "$hex" || "$hex" == "null" ]]; then
        get_data
        hex=$(cat "$json_file" | jq -r '.current_hex // "#bac2de"')
    fi
    echo "$hex"
fi