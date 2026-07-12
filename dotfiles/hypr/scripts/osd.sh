#!/usr/bin/env bash

send() {
    notify-send -a "System" -r 9990 -t 1200 -u low -i "$1" "$2" "$3"
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
    brightnessctl -n1 set 1%+ >/dev/null
    pct=$(( $(brightnessctl get) * 100 / $(brightnessctl max) ))
    send "display-brightness-high" "Brightness" "${pct}%"
    ;;
  bright-down)
    brightnessctl -n1 set 1%- >/dev/null
    pct=$(( $(brightnessctl get) * 100 / $(brightnessctl max) ))
    send "display-brightness-low" "Brightness" "${pct}%"
    ;;
#   caps-lock)
#     sleep 0.1
#     state=$(hyprctl devices -j | jq -r 'if ([.keyboards[].capsLock] | any) then "On" else "Off" end')
#     send "input-keyboard" "Caps Lock" "$state"
#     ;;
#   num-lock)
#     sleep 0.1
#     state=$(hyprctl devices -j | jq -r 'if ([.keyboards[].numLock] | any) then "On" else "Off" end')
#     send "input-keyboard" "Num Lock" "$state"
#     ;;
esac