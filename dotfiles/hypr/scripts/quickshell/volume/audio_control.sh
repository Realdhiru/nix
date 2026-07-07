#!/usr/bin/env bash
# dotfiles/hypr/scripts/quickshell/volume/audio_control.sh

ACTION=$1
TYPE=$2
ID=$3
VAL=$4

# Function to dispatch an overriding OSD notification
send_osd() {
    local icon=$1
    local title=$2
    local val=$3
    if [ "$val" = "muted" ]; then
        notify-send -a "System" -u low -h string:x-canonical-private-synchronous:sys-osd -i "$icon" "$title" "Muted"
    else
        notify-send -a "System" -u low -h string:x-canonical-private-synchronous:sys-osd -h int:value:"$val" -i "$icon" "$title" "Level: ${val}%"
    fi
}

case $ACTION in
    set-volume)
        if [[ "$ID" == "@DEFAULT@" ]]; then
            if [[ "$TYPE" == "sink" ]]; then
                wpctl set-volume @DEFAULT_AUDIO_SINK@ "$VAL"
                vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
                send_osd "audio-volume-high" "Volume" "$vol"
            elif [[ "$TYPE" == "source" ]]; then
                wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "$VAL"
                vol=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{print int($2*100)}')
                send_osd "microphone-sensitivity-high" "Microphone" "$vol"
            fi
        else
            pactl set-${TYPE}-volume "$ID" "$VAL"
        fi
        ;;
    toggle-mute)
        if [[ "$ID" == "@DEFAULT@" ]]; then
            if [[ "$TYPE" == "sink" ]]; then
                wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
                is_muted=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -o MUTED)
                if [ -n "$is_muted" ]; then
                    send_osd "audio-volume-muted" "Volume" "muted"
                else
                    vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
                    send_osd "audio-volume-high" "Volume" "$vol"
                fi
            elif [[ "$TYPE" == "source" ]]; then
                wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
                is_muted=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -o MUTED)
                if [ -n "$is_muted" ]; then
                    send_osd "microphone-sensitivity-muted" "Microphone" "muted"
                else
                    vol=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{print int($2*100)}')
                    send_osd "microphone-sensitivity-high" "Microphone" "$vol"
                fi
            fi
        else
            pactl set-${TYPE}-mute "$ID" toggle
        fi
        ;;
    set-default)
        pactl set-default-$TYPE "$ID"
        ;;
esac