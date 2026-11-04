#!/usr/bin/env bash
# Event-driven audio device auto-router, stability guard & notification watcher.
# Automatically routes audio to external devices on plug,
# automatically pauses media & falls back to speaker on unplug,
# un-mutes new sinks, eliminates cava from device enumeration,
# and guarantees audio links are never lost into thin air.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/audio"
mkdir -p "$STATE_DIR"

LOCKFILE="$STATE_DIR/watcher.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

get_eq_out_id() {
    pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_output.eq10"/ {gsub(/,/, "", id); print id; exit}' || echo ""
}

get_alsa_card_id() {
    pw-cli ls Device 2>/dev/null | awk '/id [0-9]+/ {id=$2} /device.name = "alsa_card.*platform-skl_hda_dsp/ {gsub(/,/, "", id); print id; exit}' || echo ""
}

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

route_to_sink() {
    local target_id="$1"
    local target_name="$2"
    local eq_id
    eq_id=$(get_eq_out_id)
    [ -z "$eq_id" ] && return 0

    # Ensure target sink is unmuted in hardware & WirePlumber
    wpctl set-mute "$target_id" 0 2>/dev/null || true
    pw-metadata -n default "$eq_id" target.node "$target_id" 2>/dev/null || true

    local old_links
    old_links=$(pw-link -l 2>/dev/null | awk '/effect_output.eq10:output_FL/ {
        while ((getline line) > 0) {
            if (line !~ /^[ |>-]+/) break;
            sub(/^[ |>-]+/, "", line);
            sub(/:playback_FL.*/, "", line);
            if (line !~ /cava|echo[-_]cancel/ && line != "") {
                print line;
            }
        }
    }' || echo "")

    for old in $old_links; do
        if [ "$old" != "$target_name" ]; then
            pw-link -d effect_output.eq10:output_FL "${old}:playback_FL" 2>/dev/null || true
            pw-link -d effect_output.eq10:output_FR "${old}:playback_FR" 2>/dev/null || true
        fi
    done

    pw-link effect_output.eq10:output_FL "${target_name}:playback_FL" 2>/dev/null || true
    pw-link effect_output.eq10:output_FR "${target_name}:playback_FR" 2>/dev/null || true
}

ensure_speaker_fallback() {
    local remaining_ext
    remaining_ext=$(pw-dump Node 2>/dev/null | jq -r '
      [ .[] | select(
          .info.props["media.class"] == "Audio/Sink" and
          (.info.props["node.name"] | test("effect_input|cava|echo|Speaker"; "i") | not) and
          (
            (.info.props["node.name"] | test("bluez|usb|Headphones"; "i")) or
            ((.info.props["node.description"] // "") | test("Bluetooth|Buds|AirPods|Earbuds|Headphones|USB Audio"; "i"))
          )
        ) | [.id, .info.props["node.name"]] | @tsv
      ] | .[0] // ""
    ')

    if [ -n "$remaining_ext" ]; then
        read -r rem_id rem_name <<< "$remaining_ext"
        route_to_sink "$rem_id" "$rem_name"
        return 0
    fi

    # No external sinks remain: switch ALSA profile to Speaker and link
    local alsa_id
    alsa_id=$(get_alsa_card_id)
    if [ -n "$alsa_id" ]; then
        wpctl set-profile "$alsa_id" 2 2>/dev/null || true
    fi

    local spk_info
    spk_info=$(pw-dump Node 2>/dev/null | jq -r '
      .[] | select(.info.props["node.name"] | test("HiFi__Speaker__sink$")) | [.id, .info.props["node.name"]] | @tsv
    ' | head -n 1 || echo "")

    if [ -n "$spk_info" ]; then
        read -r spk_id spk_name <<< "$spk_info"
        route_to_sink "$spk_id" "$spk_name"
    fi
}

is_external_device() {
    local name="$1"
    local desc="$2"
    local class="$3"

    [[ ! "$class" =~ ^Audio/(Sink|Source) ]] && return 1
    [[ "$name" =~ ^(effect_|echo[-_]cancel|Dummy|Freewheel|Midi|bluez_midi|v4l2|cava) ]] && return 1
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
        # Initial priming phase: record currently active nodes and ensure sound is routed & unmuted
        has_ext=false
        while IFS=$'\t' read -r id is_null name desc class; do
            [ "$is_null" = "true" ] && continue
            if is_external_device "$name" "$desc" "$class"; then
                dev_name=$(clean_name "$desc" "$name")
                tracked_devices["$id"]="$dev_name"
                if [ "$class" = "Audio/Sink" ]; then
                    has_ext=true
                    route_to_sink "$id" "$name"
                fi
            elif [[ "$name" =~ HiFi__Speaker__sink$ ]]; then
                wpctl set-mute "$id" 0 2>/dev/null || true
            fi
        done < <(echo "$line" | jq -r '.items[] | [.id, .is_null, .name, .desc, .class] | @tsv')

        if [ "$has_ext" = "false" ]; then
            ensure_speaker_fallback
        fi
    else
        # Dynamic monitor phase: auto-route on connect, auto-pause & fallback on disconnect
        while IFS=$'\t' read -r id is_null name desc class; do
            if [ "$is_null" = "true" ]; then
                if [ -n "${tracked_devices[$id]:-}" ]; then
                    dev_name="${tracked_devices[$id]}"
                    unset 'tracked_devices[$id]'

                    # 1. Immediately pause media (like macOS / Windows / iOS / Android)
                    playerctl -a pause 2>/dev/null || true

                    # 2. Notify disconnection
                    if ! is_manual_cycle && can_notify "${dev_name}_disconnected"; then
                        notify-send -a "Audio" -u low "${dev_name} Disconnected" 2>/dev/null || true
                    fi

                    # 3. Seamlessly fall back to laptop speaker (or remaining external device)
                    ensure_speaker_fallback
                fi
            else
                if [[ "$name" =~ HiFi__Speaker__sink$ ]]; then
                    # Speaker sink created (e.g. after headphone unplug)
                    wpctl set-mute "$id" 0 2>/dev/null || true
                    if [ ${#tracked_devices[@]} -eq 0 ]; then
                        route_to_sink "$id" "$name"
                    fi
                elif is_external_device "$name" "$desc" "$class"; then
                    dev_name=$(clean_name "$desc" "$name")
                    if [ -z "${tracked_devices[$id]:-}" ]; then
                        tracked_devices["$id"]="$dev_name"

                        # Auto-route if this is an audio output sink
                        if [ "$class" = "Audio/Sink" ]; then
                            route_to_sink "$id" "$name"
                        fi

                        # Send connection notification
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
