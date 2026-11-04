#!/usr/bin/env bash
set -u

notify_osd() {
    notify-send -a "System" -r "$1" -t 1200 -u low -i "$2" "$3" "$4"
}

get_audio_info() {
    local target="$1" raw vol_val vol_pct=0 mute=""
    raw=$(wpctl get-volume "$target" 2>/dev/null) || return 0
    [[ "$raw" == *"[MUTED]"* ]] && mute="muted"
    vol_val="${raw#*: }"
    vol_val="${vol_val%% *}"
    if [[ "$vol_val" =~ ^([0-9]+)\.([0-9]{2}) ]]; then
        vol_pct=$(( 100 * 10#${BASH_REMATCH[1]} + 10#${BASH_REMATCH[2]} ))
    elif [[ "$vol_val" =~ ^([0-9]+) ]]; then
        vol_pct=$(( 100 * 10#${BASH_REMATCH[1]} ))
    fi
    echo "$vol_pct $mute"
}

brightness_step() {
    local cur max pct step

    cur=$(brightnessctl get)
    max=$(brightnessctl max)

    pct=$(( cur * 100 / max ))

    if (( pct < 2 )); then
        step=1
    elif (( pct < 5 )); then
        step=$(( max / 400 ))
    elif (( pct < 10 )); then
        step=$(( max / 250 ))
    else
        step=$(( max / 20 ))   # 5% steps for >= 10%
    fi

    (( step < 1 )) && step=1

    echo "$step"
}

get_physical_sink_id() {
    local target
    target=$(pw-link -l 2>/dev/null | awk '/effect_output.eq10:output_FL/ {getline; sub(/^[ |>-]+/, ""); sub(/:playback_FL.*/, ""); print; exit}')
    if [ -n "$target" ]; then
        pw-cli ls Node 2>/dev/null | awk -v name="$target" '/id [0-9]+/ {id=$2} $0 ~ name {gsub(/,/, "", id); print id; exit}'
    fi
}

get_volume_ceiling() {
    local phys_id name
    phys_id=$(get_physical_sink_id)
    if [ -n "$phys_id" ]; then
        name=$(pw-dump "$phys_id" 2>/dev/null | jq -r '.[].info.props["node.name"] // empty' 2>/dev/null || true)
        if [[ "$name" == *"Speaker"* ]]; then
            # Safe thermal ceiling for internal laptop speaker: 120% (+1.6 dB)
            echo "1.20"
            return
        fi
    fi
    # External gear (Bluetooth, Headphones, DAC): 150% (+3.5 dB)
    echo "1.50"
}

case "${1:-}" in
    vol-up)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
        limit=$(get_volume_ceiling)
        wpctl set-volume -l "$limit" @DEFAULT_AUDIO_SINK@ 5%+
        cur_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}')
        if [ "$(awk -v c="${cur_raw:-1.0}" -v l="$limit" 'BEGIN { print (c > l) ? 1 : 0 }')" -eq 1 ]; then
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "$limit"
        fi
        read -r pct mute < <(get_audio_info @DEFAULT_AUDIO_SINK@)
        icon="audio-volume-high"
        (( pct < 30 )) && icon="audio-volume-low"
        (( pct >= 30 && pct < 70 )) && icon="audio-volume-medium"
        notify_osd 9990 "$icon" "Volume" "${pct}%"
        ;;
    vol-down)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
        limit=$(get_volume_ceiling)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        cur_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}')
        if [ "$(awk -v c="${cur_raw:-1.0}" -v l="$limit" 'BEGIN { print (c > l) ? 1 : 0 }')" -eq 1 ]; then
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "$limit"
        fi
        read -r pct mute < <(get_audio_info @DEFAULT_AUDIO_SINK@)
        icon="audio-volume-high"
        (( pct < 30 )) && icon="audio-volume-low"
        (( pct >= 30 && pct < 70 )) && icon="audio-volume-medium"
        notify_osd 9990 "$icon" "Volume" "${pct}%"
        ;;
    vol-mute)
        limit=$(get_volume_ceiling)
        cur_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}')
        if [ "$(awk -v c="${cur_raw:-1.0}" -v l="$limit" 'BEGIN { print (c > l) ? 1 : 0 }')" -eq 1 ]; then
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "$limit"
        fi
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        read -r pct mute < <(get_audio_info @DEFAULT_AUDIO_SINK@)
        if [ "$mute" = "muted" ]; then
            notify_osd 9990 "audio-volume-muted" "Volume" "${pct}% (Muted)"
        else
            icon="audio-volume-high"
            (( pct < 30 )) && icon="audio-volume-low"
            (( pct >= 30 && pct < 70 )) && icon="audio-volume-medium"
            notify_osd 9990 "$icon" "Volume" "${pct}%"
        fi
        ;;
    mic-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        read -r pct mute < <(get_audio_info @DEFAULT_AUDIO_SOURCE@)
        if [ "$mute" = "muted" ]; then
            notify_osd 9991 "microphone-sensitivity-muted" "Microphone" "Muted"
        else
            notify_osd 9991 "microphone-sensitivity-high" "Microphone" "Unmuted"
        fi
        ;;
    bright-up)
        brightnessctl -n1 set +"$(brightness_step)" >/dev/null
        cur=$(brightnessctl get)
        max=$(brightnessctl max)
        pct=$(( (cur * 100 + max / 2) / max ))
        icon="display-brightness-high"
        (( pct < 35 )) && icon="display-brightness-low"
        (( pct >= 35 && pct < 70 )) && icon="display-brightness-medium"
        notify_osd 9992 "$icon" "Brightness" "${pct}%"
        ;;
    bright-down)
        brightnessctl -n1 set "$(brightness_step)"- >/dev/null
        cur=$(brightnessctl get)
        max=$(brightnessctl max)
        pct=$(( (cur * 100 + max / 2) / max ))
        icon="display-brightness-high"
        (( pct < 35 )) && icon="display-brightness-low"
        (( pct >= 35 && pct < 70 )) && icon="display-brightness-medium"
        notify_osd 9992 "$icon" "Brightness" "${pct}%"
        ;;
esac