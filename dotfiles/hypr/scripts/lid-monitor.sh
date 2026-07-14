#!/usr/bin/env bash

LID=$(echo /proc/acpi/button/lid/LID*)

last=""

while true; do
    state=$(awk '{print $2}' "$LID/state")

    if [[ "$state" != "$last" ]]; then
        if [[ "$state" == "closed" ]]; then
            hyprctl dispatch dpms off
        else
            hyprctl dispatch dpms on
        fi
        last="$state"
    fi

    sleep 0.2
done