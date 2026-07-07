# ==> /home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/watchers/audio_fetch.sh <==
#!/usr/bin/env bash

fetch_audio_state() {
    local dump=""
    local vol=0
    local muted="false"
    local icon="󰝟"

    if command -v wpctl &> /dev/null; then
        dump=$(LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        vol=$(echo "$dump" | awk '{print int($2*100)}')
        if echo "$dump" | grep -q "MUTED"; then muted="true"; fi
    elif command -v pamixer &> /dev/null; then
        vol=$(LC_ALL=C pamixer --get-volume 2>/dev/null)
        if LC_ALL=C pamixer --get-mute 2>/dev/null | grep -q "true"; then muted="true"; fi
    fi

    vol=${vol:-0}

    if [ "$muted" = "true" ]; then icon="󰝟"
    elif [ "$vol" -ge 70 ]; then icon="󰕾"
    elif [ "$vol" -ge 30 ]; then icon="󰖀"
    elif [ "$vol" -gt 0 ]; then icon="󰕿"
    else icon="󰝟"; fi

    echo "$vol|$muted|$icon"
}

toggle_mute() {
    if command -v wpctl &> /dev/null; then
        LC_ALL=C wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    elif command -v pamixer &> /dev/null; then
        LC_ALL=C pamixer --toggle-mute 2>/dev/null
    fi

    IFS='|' read -r vol muted icon <<< "$(fetch_audio_state)"
    if [ "$muted" = "true" ]; then notify-send -u low -i audio-volume-muted "Volume" "Muted"
    else notify-send -u low -i audio-volume-high "Volume" "Unmuted (${vol}%)"; fi
}

case ${1:-} in
    --toggle) toggle_mute ;;
    *)
        IFS='|' read -r vol muted icon <<< "$(fetch_audio_state)"
        jq -n -c --arg volume "$vol" --arg icon "$icon" --arg is_muted "$muted" '{volume: $volume, icon: $icon, is_muted: $is_muted}'
        ;;
esac