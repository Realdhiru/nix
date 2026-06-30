#!/usr/bin/env bash

# POWER OPTIMIZATION: Uses pure Bash built-ins to read kernel nodes. No sub-process forks!
get_battery_percent() {
    local cap_file
    for cap_file in /sys/class/power_supply/BAT*/capacity; do
        if [ -f "$cap_file" ]; then
            read -r percent < "$cap_file"
            echo "${percent:-100}"
            return 0
        fi
    done
    echo "100"
}

get_battery_status() {
    local stat_file
    for stat_file in /sys/class/power_supply/BAT*/status; do
        if [ -f "$stat_file" ]; then
            read -r status < "$stat_file"
            echo "${status:-Full}"
            return 0
        fi
    done
    echo "Full"
}

get_battery_icon() {
    local percent=$(get_battery_percent)
    local status=$(get_battery_status)
    if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
        if [ "$percent" -ge 90 ]; then echo "󰂅"
        elif [ "$percent" -ge 80 ]; then echo "󰂋"
        elif [ "$percent" -ge 60 ]; then echo "󰂊"
        elif [ "$percent" -ge 40 ]; then echo "󰢞"
        elif [ "$percent" -ge 20 ]; then echo "󰂆"
        else echo "󰢜"; fi
    else
        if [ "$percent" -ge 90 ]; then echo "󰁹"
        elif [ "$percent" -ge 80 ]; then echo "󰂂"
        elif [ "$percent" -ge 70 ]; then echo "󰂁"
        elif [ "$percent" -ge 60 ]; then echo "󰂀"
        elif [ "$percent" -ge 50 ]; then echo "󰁿"
        elif [ "$percent" -ge 40 ]; then echo "󰁾"
        elif [ "$percent" -ge 30 ]; then echo "󰁽"
        elif [ "$percent" -ge 20 ]; then echo "󰁼"
        elif [ "$percent" -ge 10 ]; then echo "󰁻"
        else echo "󰁺"; fi
    fi
}

jq -n -c --arg percent "$(get_battery_percent)" --arg status "$(get_battery_status)" --arg icon "$(get_battery_icon)" '{percent: $percent, status: $status, icon: $icon}'