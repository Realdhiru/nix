#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# CACHING & MIGRATION
# -----------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "weather"

export LC_ALL=C

# Paths
cache_dir="$QS_CACHE_WEATHER"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"
daily_cache_file="${cache_dir}/daily_weather_cache.json"
next_day_cache_file="${cache_dir}/next_day_precache.json"

# -----------------------------------------------------------------------------
# SECRETS MANAGEMENT (NIXOS SAFE)
# -----------------------------------------------------------------------------
SECRET_FILE="$HOME/nix/dotfiles/secrets/openweather.json"

if [ -f "$SECRET_FILE" ]; then
    KEY=$(jq -r '.api_key // empty' "$SECRET_FILE")
    ID=$(jq -r '.city_id // empty' "$SECRET_FILE")
    UNIT=$(jq -r '.unit // "metric"' "$SECRET_FILE")
else
    KEY=""
    ID=""
    UNIT="metric"
fi

case "$UNIT" in
    "imperial") UNIT_SYM="°F" ;;
    "standard") UNIT_SYM="K" ;;
    *) UNIT_SYM="°C" ;;
esac

mkdir -p "${cache_dir}"

get_icon() {
    case $1 in
        "50d"|"50n") icon="󰖑"; quote="Mist" ;;
        "01d") icon=""; quote="Sunny" ;;
        "01n") icon=""; quote="Clear" ;;
        "02d"|"02n"|"03d"|"03n"|"04d"|"04n") icon=""; quote="Cloudy" ;;
        "09d"|"09n"|"10d"|"10n") icon="󰖗"; quote="Rainy" ;;
        "11d"|"11n") icon=""; quote="Storm" ;;
        "13d"|"13n") icon=""; quote="Snow" ;;
        *) icon=""; quote="Unknown" ;;
    esac
    echo "$icon|$quote"
}

get_hex() {
    case $1 in
        "50d"|"50n") echo "#84afdb" ;;
        "01d") echo "#f9e2af" ;;
        "01n") echo "#cba6f7" ;;
        "02d"|"02n"|"03d"|"03n"|"04d"|"04n") echo "#bac2de" ;;
        "09d"|"09n"|"10d"|"10n") echo "#74c7ec" ;;
        "11d"|"11n") echo "#f9e2af" ;;
        "13d"|"13n") echo "#cdd6f4" ;;
        *) echo "#cdd6f4" ;;
    esac
}

write_dummy_data() {
    final_json="["
    for i in {0..4}; do
        future_date=$(date -d "+$i days")
        f_day=$(date -d "$future_date" "+%a")
        f_full_day=$(date -d "$future_date" "+%A")
        f_date_num=$(date -d "$future_date" "+%d %b")

        final_json="${final_json} {
            \"id\": \"${i}\",
            \"day\": \"${f_day}\",
            \"day_full\": \"${f_full_day}\",
            \"date\": \"${f_date_num}\",
            \"max\": \"0.0\",
            \"min\": \"0.0\",
            \"feels_like\": \"0.0\",
            \"wind\": \"0\",
            \"humidity\": \"0\",
            \"pop\": \"0\",
            \"icon\": \"\",
            \"hex\": \"#cdd6f4\",
            \"desc\": \"No API Key\",
            \"hourly\": [{\"time\": \"00:00\", \"temp\": \"0.0\", \"icon\": \"\", \"hex\": \"#cdd6f4\"}]
        },"
    done
    final_json="${final_json%,}]"
    echo "{ \"current_temp\": \"0.0\", \"current_icon\": \"\", \"current_hex\": \"#cdd6f4\", \"forecast\": ${final_json} }" > "${json_file}"
}

get_data() {
    if [[ -z "$KEY" || "$KEY" == "Skipped" || "$KEY" == "OPENWEATHER_KEY" ]]; then
        write_dummy_data
        return
    fi

    forecast_url="http://api.openweathermap.org/data/2.5/forecast?APPID=${KEY}&id=${ID}&units=${UNIT}"
    raw_api=$(curl -sf "$forecast_url" || echo "")

    weather_url="http://api.openweathermap.org/data/2.5/weather?APPID=${KEY}&id=${ID}&units=${UNIT}"
    raw_weather=$(curl -sf "$weather_url" || echo "")

    api_cod=$(echo "$raw_api" | jq -r '.cod // empty' 2>/dev/null || echo "")

    if [ -z "$raw_api" ] || [ -z "$raw_weather" ] || [[ "$api_cod" != "200" ]]; then
        if [ ! -f "$json_file" ]; then write_dummy_data; fi
        return
    fi

    # Parse LIVE current weather with safe null-fallbacks
    c_temp=$(echo "$raw_weather" | jq -r '.main.temp // 0')
    c_temp=$(printf "%.1f" "$c_temp")
    c_code=$(echo "$raw_weather" | jq -r '.weather[0].icon // "02d"')
    c_icon=$(get_icon "$c_code" | cut -d'|' -f1)
    c_hex=$(get_hex "$c_code")

    current_date=$(date +%Y-%m-%d)
    tomorrow_date=$(date -d "tomorrow" +%Y-%m-%d)

    # 1. ROLLOVER CHECK
    if [ -f "$next_day_cache_file" ]; then
        precache_date=$(cat "$next_day_cache_file" | jq -r '.[0].dt_txt // empty' | cut -d' ' -f1 || echo "")
        if [ "$precache_date" == "$current_date" ]; then
            mv "$next_day_cache_file" "$daily_cache_file"
        fi
    fi

    # 2. PROCESS TODAY
    api_today_items=$(echo "$raw_api" | jq -c ".list[] | select(.dt_txt | startswith(\"$current_date\"))" | jq -s '.')

    if [ -f "$daily_cache_file" ]; then
        cached_date=$(cat "$daily_cache_file" | jq -r '.[0].dt_txt // empty' | cut -d' ' -f1 || echo "")
        if [ "$cached_date" == "$current_date" ]; then
            merged_today=$(echo "$api_today_items" | jq --slurpfile cache "$daily_cache_file" '($cache[0] + .) | unique_by(.dt) | sort_by(.dt)')
        else
            merged_today="$api_today_items"
        fi
    else
        merged_today="$api_today_items"
    fi

    echo "$merged_today" > "$daily_cache_file"

    # 3. PRE-CACHE TOMORROW
    echo "$raw_api" | jq -c ".list[] | select(.dt_txt | startswith(\"$tomorrow_date\"))" | jq -s '.' > "$next_day_cache_file"

    # 4. BUILD FINAL JSON
    processed_forecast=$(echo "$raw_api" | jq --argjson today "$merged_today" --arg date "$current_date" '.list = ($today + [.list[] | select(.dt_txt | startswith($date) | not)])')

    if [ -n "$processed_forecast" ]; then
        dates=$(echo "$processed_forecast" | jq -r '.list[].dt_txt | split(" ")[0]' | uniq | head -n 5)

        final_json="["
        counter=0

        for d in $dates; do
            day_data=$(echo "$processed_forecast" | jq "[.list[] | select(.dt_txt | startswith(\"$d\"))]")

            # FAST BATCH EXTRACTION: Using '// 0' ensures bash doesn't crash on missing json keys
            read -r raw_max raw_min raw_feels f_pop f_wind f_hum f_code f_desc <<< $(echo "$day_data" | jq -r '
                ([.[].main.temp_max] | max // 0) as $max |
                ([.[].main.temp_min] | min // 0) as $min |
                ([.[].main.feels_like] | max // 0) as $feels |
                ([.[].pop] | max // 0) as $pop |
                ([.[].wind.speed] | max // 0 | round) as $wind |
                ([.[].main.humidity] | add / length // 0 | round) as $hum |
                .[length/2 | floor].weather[0] as $w |
                "\($max) \($min) \($feels) \($pop) \($wind) \($hum) \($w.icon // "02d") \($w.description // "Unknown")"
            ')

            f_max_temp=$(printf "%.1f" "$raw_max")
            f_min_temp=$(printf "%.1f" "$raw_min")
            f_feels_like=$(printf "%.1f" "$raw_feels")
            
            f_pop_pct=$(awk "BEGIN {print int($f_pop * 100)}")

            f_desc=$(echo "$f_desc" | sed -e "s/\b\(.\)/\u\1/g")
            f_icon=$(get_icon "$f_code" | cut -d'|' -f1)
            f_hex=$(get_hex "$f_code")

            f_day=$(date -d "$d" "+%a")
            f_full_day=$(date -d "$d" "+%A")
            f_date_num=$(date -d "$d" "+%d %b")

            hourly_json="["
            
            while read -r s_dt raw_s_temp s_code; do
                [ -z "$s_dt" ] && continue
                s_time=$(date -d "@$s_dt" "+%H:%M")
                s_temp=$(printf "%.1f" "$raw_s_temp")
                s_hex=$(get_hex "$s_code")
                s_icon=$(get_icon "$s_code" | cut -d'|' -f1)
                hourly_json="${hourly_json} {\"time\": \"${s_time}\", \"temp\": \"${s_temp}\", \"icon\": \"${s_icon}\", \"hex\": \"${s_hex}\"},"
            done <<< $(echo "$day_data" | jq -r '.[] | "\(.dt // 0) \(.main.temp // 0) \(.weather[0].icon // "02d")"')
            
            hourly_json="${hourly_json%,}]"
            if [ "$hourly_json" == "]" ]; then hourly_json="[]"; fi

            final_json="${final_json} {
                \"id\": \"${counter}\",
                \"day\": \"${f_day}\",
                \"day_full\": \"${f_full_day}\",
                \"date\": \"${f_date_num}\",
                \"max\": \"${f_max_temp}\",
                \"min\": \"${f_min_temp}\",
                \"feels_like\": \"${f_feels_like}\",
                \"wind\": \"${f_wind}\",
                \"humidity\": \"${f_hum}\",
                \"pop\": \"${f_pop_pct}\",
                \"icon\": \"${f_icon}\",
                \"hex\": \"${f_hex}\",
                \"desc\": \"${f_desc}\",
                \"hourly\": ${hourly_json}
            },"
            ((counter++))
        done
        final_json="${final_json%,}]"

        echo "{ \"current_temp\": \"${c_temp}\", \"current_icon\": \"${c_icon}\", \"current_hex\": \"${c_hex}\", \"forecast\": ${final_json} }" > "${json_file}"
    fi
}

# --- MODE HANDLING ---
if [[ "$1" == "--getdata" ]]; then
    get_data
elif [[ "$1" == "--json" ]]; then
    CACHE_LIMIT=900         
    PENDING_RETRY_LIMIT=3600 

    if [ -f "$json_file" ]; then
        file_time=$(stat -c %Y "$json_file")
        current_time=$(date +%s)
        diff=$((current_time - file_time))

        if grep -q '"desc": "No API Key"' "$json_file"; then
            if [ $diff -gt $PENDING_RETRY_LIMIT ]; then
                touch "$json_file" 
                get_data &
            fi
        else
            if [ $diff -gt $CACHE_LIMIT ]; then
                touch "$json_file"
                get_data &
            fi
        fi
        cat "$json_file"
    else
        get_data
        cat "$json_file"
    fi
elif [[ "$1" == "--view-listener" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    tail -F "$view_file"
elif [[ "$1" == "--nav" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    current=$(cat "$view_file")
    direction=$2
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
elif [[ "$1" == "--icon" ]]; then
    cat "$json_file" | jq -r '.forecast[0].icon'
elif [[ "$1" == "--temp" ]]; then
    t=$(cat "$json_file" | jq -r '.forecast[0].max')
    echo "${t}${UNIT_SYM}"
elif [[ "$1" == "--hex" ]]; then
    cat "$json_file" | jq -r '.forecast[0].hex'
elif [[ "$1" == "--current-icon" ]]; then
    icon=$(cat "$json_file" | jq -r '.current_icon // empty')
    if [[ -z "$icon" || "$icon" == "null" ]]; then
        get_data
        icon=$(cat "$json_file" | jq -r '.current_icon')
    fi
    echo "$icon"
elif [[ "$1" == "--current-temp" ]]; then
    t=$(cat "$json_file" | jq -r '.current_temp // empty')
    if [[ -z "$t" || "$t" == "null" ]]; then
        get_data
        t=$(cat "$json_file" | jq -r '.current_temp')
    fi
    echo "${t}${UNIT_SYM}"
elif [[ "$1" == "--current-hex" ]]; then
    hex=$(cat "$json_file" | jq -r '.current_hex // empty')
    if [[ -z "$hex" || "$hex" == "null" ]]; then
        get_data
        hex=$(cat "$json_file" | jq -r '.current_hex')
    fi
    echo "$hex"
fi