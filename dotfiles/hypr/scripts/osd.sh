#!/usr/bin/env bash

send() {
    notify-send -a "System" -r 9990 -t 1200 -u low -i "$1" "$2" "$3"
}

brightness_step() {
    local cur max pct step

    cur=$(brightnessctl get)
    max=$(brightnessctl max)

    # Current brightness percentage (0-100)
    pct=$(( cur * 100 / max ))

    # Smooth adaptive curve.
    #
    # Lowest brightness:
    #   Always 1 hardware step (finest possible precision).
    #
    # Higher brightness:
    #   Step gradually increases based on hardware max,
    #   making it feel identical across laptops.

    if (( pct < 2 )); then
        step=1
    elif (( pct < 5 )); then
        step=$(( max / 400 ))
    elif (( pct < 10 )); then
        step=$(( max / 250 ))
    elif (( pct < 20 )); then
        step=$(( max / 180 ))
    elif (( pct < 35 )); then
        step=$(( max / 120 ))
    elif (( pct < 50 )); then
        step=$(( max / 80 ))
    elif (( pct < 70 )); then
        step=$(( max / 60 ))
    elif (( pct < 85 )); then
        step=$(( max / 40 ))
    else
        step=$(( max / 30 ))
    fi

    # Never allow 0-step on low-resolution backlights.
    (( step < 1 )) && step=1

    echo "$step"
}

brightness_osd() {
    local cur max pct

    cur=$(brightnessctl get)
    max=$(brightnessctl max)

    pct=$(awk "BEGIN { printf \"%.1f\", ($cur/$max)*100 }")

    send "$1" "Brightness" "${pct}%"
}

case "$1" in
    vol-up)
        wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
        pct=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
        send "audio-volume-high" "Volume" "${pct}%"
        ;;

    vol-down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        pct=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
        send "audio-volume-low" "Volume" "${pct}%"
        ;;

    vol-mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED; then
            send "audio-volume-muted" "Volume" "Muted"
        else
            send "audio-volume-high" "Volume" "Unmuted"
        fi
        ;;

    mic-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
            send "microphone-sensitivity-muted" "Microphone" "Muted"
        else
            send "microphone-sensitivity-high" "Microphone" "Unmuted"
        fi
        ;;

    bright-up)
        brightnessctl -n1 set +"$(brightness_step)" >/dev/null
        brightness_osd "display-brightness-high"
        ;;

    bright-down)
        brightnessctl -n1 set "$(brightness_step)"- >/dev/null
        brightness_osd "display-brightness-low"
        ;;
esac