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

# Real AC-plugged-in state, independent of the battery's own "status"
# string. On a charge-threshold-capped battery (STOP_CHARGE_THRESH_BAT0 in
# power.nix), the kernel reports status="Not charging" once the cap is
# hit even though the charger is physically connected -- so anything keyed
# off status alone goes blind to "plugged in" above that percentage. This
# reads the actual AC adapter's online sysfs value instead.
get_ac_online() {
    local file val
    for file in /sys/class/power_supply/*/online; do
        [[ -r "$file" ]] || continue
        read -r val < "$file"
        printf '%s\n' "${val:-1}"
        return
    done
    printf '1\n'
}

has_battery() {
    local file
    for file in /sys/class/power_supply/BAT*/capacity; do
        [[ -r "$file" ]] && { printf '1\n'; return; }
    done
    printf '0\n'
}

get_battery_icon() {
    local percent=$1
    local online=$2

    if [[ "$online" == "1" ]]; then
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
online=$(get_ac_online)
has=$(has_battery)
# Icon now keys off the real AC-online signal, not the status string.
icon=$(get_battery_icon "$percent" "$online")

jq -nc \
    --arg percent "$percent" \
    --arg status "$status" \
    --arg icon "$icon" \
    --arg online "$online" \
    --arg has "$has" \
    '{percent:$percent,status:$status,icon:$icon,online:$online,has:$has}'