#!/usr/bin/env bash
# Event-driven audio device connection & disconnection watcher
# Uses PipeWire monitor stream without polling or sleep hacks.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/audio"
mkdir -p "$STATE_DIR"

LOCKFILE="$STATE_DIR/watcher.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

is_manual_cycle() {
    local ts_file="$STATE_DIR/manual_cycle_ts"
    if [ -f "$ts_file" ]; then
        local last_ts now diff
        last_ts=$(cat "$ts_file" 2>/dev/null || echo 0)
        now=$(date +%s)
        diff=$(( now - last_ts ))
        if [ "$diff" -ge 0 ] && [ "$diff" -le 3 ]; then
            return 0
        fi
    fi
    return 1
}

declare -A last_notify_times
can_notify() {
    local key="$1"
    local now
    now=$(date +%s)
    local last_time="${last_notify_times[$key]:-0}"
    if [ $(( now - last_time )) -lt 2 ]; then
        return 1
    fi
    last_notify_times["$key"]=$now
    return 0
}

is_external_device() {
    local name="$1"
    local desc="$2"
    local class="$3"

    [[ ! "$class" =~ ^Audio/(Sink|Source) ]] && return 1
    [[ "$name" =~ ^(effect_|echo[-_]cancel|Dummy|Freewheel|Midi|bluez_midi|v4l2) ]] && return 1
    [[ "$name" =~ HiFi__(Speaker__sink|Mic1__source|Mic2__source) ]] && return 1
    [[ "$name" =~ HiFi__HDMI ]] && return 1

    if [[ "$name" =~ HiFi__Headphones__sink ]] || [[ "$name" =~ ^bluez_ ]] || [[ "$name" =~ usb ]] || [[ "$desc" =~ (Bluetooth|Buds|AirPods|Earbuds|Headphone|USB|DAC) ]]; then
        return 0
    fi
    return 1
}

clean_name() {
    local desc="$1"
    local name="$2"

    if [[ "$name" =~ HiFi__Headphones__sink ]]; then
        echo "Headphones"
        return
    fi
    if [[ "$name" =~ [Hh][Dd][Mm][Ii] ]]; then
        echo "HDMI Audio"
        return
    fi

    local cleaned
    cleaned=$(echo "$desc" | sed -E "s/\[[^]]*\]//g; s/\([^)]*\)//g; s/[^a-zA-Z0-9 -]/ /g" | awk '{$1=$1};1')
    cleaned=$(echo "$cleaned" | sed -E "s/\b(Wireless|Noise-Canceling|Stereo|Headset|Headphones|Audio)\b//gi" | awk '{$1=$1};1')
    local count
    count=$(echo "$cleaned" | wc -w)
    if [ "$count" -gt 2 ]; then
        cleaned=$(echo "$cleaned" | awk '{print $1, $2}')
    fi
    if [ -z "$cleaned" ]; then
        if [[ "$name" =~ ^bluez_ ]]; then
            cleaned="Bluetooth"
        elif [[ "$name" =~ usb ]]; then
            cleaned="USB Audio"
        else
            cleaned="Audio Device"
        fi
    fi
    echo "$cleaned"
}

declare -A tracked_devices

while IFS= read -r line; do
    batch=$(echo "$line" | jq -r '.batch // 0')
    if [ "$batch" -eq 1 ]; then
        # Initial priming phase: record currently active nodes without notifying
        while IFS=$'\t' read -r id is_null name desc class; do
            [ "$is_null" = "true" ] && continue
            if is_external_device "$name" "$desc" "$class"; then
                dev_name=$(clean_name "$desc" "$name")
                tracked_devices["$id"]="$dev_name"
            fi
        done < <(echo "$line" | jq -r '.items[] | [.id, .is_null, .name, .desc, .class] | @tsv')
    else
        # Dynamic monitor phase: notify on external device connect / disconnect
        while IFS=$'\t' read -r id is_null name desc class; do
            if [ "$is_null" = "true" ]; then
                if [ -n "${tracked_devices[$id]:-}" ]; then
                    dev_name="${tracked_devices[$id]}"
                    unset 'tracked_devices[$id]'
                    if ! is_manual_cycle && can_notify "${dev_name}_disconnected"; then
                        notify-send -a "Audio" -u low "${dev_name} Disconnected" 2>/dev/null || true
                    fi
                fi
            else
                if is_external_device "$name" "$desc" "$class"; then
                    dev_name=$(clean_name "$desc" "$name")
                    if [ -z "${tracked_devices[$id]:-}" ]; then
                        tracked_devices["$id"]="$dev_name"
                        if ! is_manual_cycle && can_notify "${dev_name}_connected"; then
                            notify-send -a "Audio" -u low "${dev_name} Connected" 2>/dev/null || true
                        fi
                    fi
                fi
            fi
        done < <(echo "$line" | jq -r '.items[] | [.id, .is_null, .name, .desc, .class] | @tsv')
    fi
done < <(pw-dump -N -m Node 2>/dev/null | jq --unbuffered -c -n '
  foreach inputs as $arr (0; . + 1; {
    batch: .,
    items: [ $arr[] | {
      id: .id,
      is_null: (.info == null),
      name: (.info.props["node.name"] // ""),
      desc: (.info.props["node.description"] // .info.props["node.nick"] // .info.props["node.name"] // ""),
      class: (.info.props["media.class"] // "")
    } ]
  })
')
