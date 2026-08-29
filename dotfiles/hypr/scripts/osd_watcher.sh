#!/usr/bin/env bash
# osd_watcher.sh -- Event-driven Volume, Microphone, & Brightness OSD Daemon
# Triggers OSD notifications whenever actual system audio/brightness states change.

set -u

# Ensure single instance
me_pid=$$
for pid in $(pgrep -f "osd_watcher.sh" 2>/dev/null); do
    if [ "$pid" -ne "$me_pid" ]; then
        kill "$pid" 2>/dev/null || true
    fi
done

notify_osd() {
    local replace_id="$1"
    local icon="$2"
    local title="$3"
    local body="$4"
    notify-send -a "System" -r "$replace_id" -t 1200 -u low -i "$icon" "$title" "$body"
}

# 1. AUDIO & MICROPHONE WATCHER LOOP
(
    last_vol=""
    last_sink_mute=""
    last_mic_mute=""

    check_audio() {
        local raw_sink raw_mic
        raw_sink=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || return 0
        raw_mic=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null) || return 0

        local vol_pct sink_mute mic_mute
        vol_pct=$(echo "$raw_sink" | awk '{print int($2*100)}')
        if echo "$raw_sink" | grep -q "MUTED"; then
            sink_mute="muted"
        else
            sink_mute="unmuted"
        fi

        if echo "$raw_mic" | grep -q "MUTED"; then
            mic_mute="muted"
        else
            mic_mute="unmuted"
        fi

        # Skip notification on initial baseline pass
        if [ -n "$last_vol" ]; then
            # Sink volume / mute change
            if [ "$sink_mute" != "$last_sink_mute" ]; then
                if [ "$sink_mute" = "muted" ]; then
                    notify_osd 9990 "audio-volume-muted" "Volume" "${vol_pct}% (Muted)"
                else
                    local icon="audio-volume-high"
                    if [ "$vol_pct" -lt 30 ]; then icon="audio-volume-low";
                    elif [ "$vol_pct" -lt 70 ]; then icon="audio-volume-medium"; fi
                    notify_osd 9990 "$icon" "Volume" "${vol_pct}%"
                fi
            elif [ "$vol_pct" != "$last_vol" ]; then
                if [ "$sink_mute" = "muted" ]; then
                    notify_osd 9990 "audio-volume-muted" "Volume" "${vol_pct}% (Muted)"
                else
                    local icon="audio-volume-high"
                    if [ "$vol_pct" -lt 30 ]; then icon="audio-volume-low";
                    elif [ "$vol_pct" -lt 70 ]; then icon="audio-volume-medium"; fi
                    notify_osd 9990 "$icon" "Volume" "${vol_pct}%"
                fi
            fi

            # Mic mute change
            if [ "$mic_mute" != "$last_mic_mute" ]; then
                if [ "$mic_mute" = "muted" ]; then
                    notify_osd 9991 "microphone-sensitivity-muted" "Microphone" "Muted"
                else
                    notify_osd 9991 "microphone-sensitivity-high" "Microphone" "Unmuted"
                fi
            fi
        fi

        last_vol="$vol_pct"
        last_sink_mute="$sink_mute"
        last_mic_mute="$mic_mute"
    }

    # Record baseline state silently
    check_audio

    # Listen to pipewire monitoring events (auto-reconnect on resume/reset)
    while true; do
        pw-mon 2>/dev/null | grep --line-buffered -E "param: Props|changed|id:" | while read -r _; do
            check_audio
        done
        sleep 1
    done
) &

# 2. BRIGHTNESS WATCHER LOOP
(
    last_bright=""

    check_bright() {
        local cur max pct
        cur=$(brightnessctl get 2>/dev/null) || return 0
        max=$(brightnessctl max 2>/dev/null) || return 0
        [ "$max" -gt 0 ] || return 0
        pct=$(( cur * 100 / max ))

        if [ -n "$last_bright" ] && [ "$pct" != "$last_bright" ]; then
            local icon="display-brightness-high"
            if [ "$pct" -lt 35 ]; then icon="display-brightness-low";
            elif [ "$pct" -lt 70 ]; then icon="display-brightness-medium"; fi
            notify_osd 9992 "$icon" "Brightness" "${pct}%"
        fi
        last_bright="$pct"
    }

    # Record baseline state silently
    check_bright

    backlight_dir=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n 1)
    if [ -n "$backlight_dir" ] && command -v inotifywait >/dev/null 2>&1; then
        while true; do
            inotifywait -q -m -e modify "$backlight_dir/brightness" 2>/dev/null | while read -r _; do
                check_bright
            done
            sleep 1
        done
    else
        while true; do
            sleep 0.2
            check_bright
        done
    fi
) &

wait
