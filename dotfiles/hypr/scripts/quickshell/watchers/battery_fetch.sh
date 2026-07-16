#!/usr/bin/env bash

get_battery_percent() {
    local file percent
    for file in /sys/class/power_supply/BAT*/capacity; do
        [[ -r "$file" ]] || continue
        read -r percent < "$file"
        printf '%s\n' "${percent:-100}"
        return
    done
    printf '100\n'
}

get_battery_status() {
    local file status
    for file in /sys/class/power_supply/BAT*/status; do
        [[ -r "$file" ]] || continue
        read -r status < "$file"
        printf '%s\n' "${status:-Unknown}"
        return
    done
    printf 'Unknown\n'
}

get_battery_icon() {
    local percent=$1
    local status=$2

    if [[ "$status" == "Charging" || "$status" == "Full" ]]; then
        (( percent >= 90 )) && printf '󰂅\n' && return
        (( percent >= 80 )) && printf '󰂋\n' && return
        (( percent >= 60 )) && printf '󰂊\n' && return
        (( percent >= 40 )) && printf '󰢞\n' && return
        (( percent >= 20 )) && printf '󰂆\n' && return
        printf '󰢜\n'
    else
        (( percent >= 90 )) && printf '󰁹\n' && return
        (( percent >= 80 )) && printf '󰂂\n' && return
        (( percent >= 70 )) && printf '󰂁\n' && return
        (( percent >= 60 )) && printf '󰂀\n' && return
        (( percent >= 50 )) && printf '󰁿\n' && return
        (( percent >= 40 )) && printf '󰁾\n' && return
        (( percent >= 30 )) && printf '󰁽\n' && return
        (( percent >= 20 )) && printf '󰁼\n' && return
        (( percent >= 10 )) && printf '󰁻\n' && return
        printf '󰁺\n'
    fi
}

percent=$(get_battery_percent)
if ! [[ "$percent" =~ ^[0-9]+$ ]] || [ "$percent" -gt 100 ]; then
    percent=100
fi
status=$(get_battery_status)
icon=$(get_battery_icon "$percent" "$status")

jq -nc \
    --arg percent "$percent" \
    --arg status "$status" \
    --arg icon "$icon" \
    '{percent:$percent,status:$status,icon:$icon}'