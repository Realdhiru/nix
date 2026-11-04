#!/usr/bin/env bash
# Event-driven audio auto-router & stability guard.
# - Auto-routes audio OUTPUT to any external device that connects (Bluetooth, USB, Headphones).
# - Pauses media only on DISCONNECT then falls back to speaker (macOS/Windows/iOS behavior).
# - Sends 1-3 word connect/disconnect notifications.
# - No polling, no sleep, event-driven only.
set -eo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/audio"
mkdir -p "$STATE_DIR"

LOCKFILE="$STATE_DIR/watcher.lock"
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

TRACKED_DIR="$STATE_DIR/tracked"
mkdir -p "$TRACKED_DIR"
# Clean stale tracking files from previous session
rm -f "$TRACKED_DIR"/*.node 2>/dev/null || true

get_eq_out_id() {
    pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_output.eq10"/ {gsub(/,/, "", id); print id; exit}' || echo ""
}

get_alsa_card_id() {
    pw-cli ls Device 2>/dev/null | awk '/id [0-9]+/ {id=$2} /device.name = "alsa_card.*platform-skl_hda_dsp/ {gsub(/,/, "", id); print id; exit}' || echo ""
}

is_manual_cycle() {
    local ts_file="$STATE_DIR/manual_cycle_ts"
    [ ! -f "$ts_file" ] && return 1
    local last_ts now diff
    last_ts=$(cat "$ts_file" 2>/dev/null || echo 0)
    now=$(date +%s)
    diff=$(( now - last_ts ))
    [ "$diff" -ge 0 ] && [ "$diff" -le 3 ]
}

last_notify_time() { cat "$STATE_DIR/notify_${1//\//_}" 2>/dev/null || echo 0; }
set_notify_time() { echo "$(date +%s)" > "$STATE_DIR/notify_${1//\//_}"; }
can_notify() {
    local key="$1" now last
    now=$(date +%s)
    last=$(last_notify_time "$key")
    [ $(( now - last )) -ge 2 ] || return 1
    set_notify_time "$key"
}

track_add()  { echo "$2" > "$TRACKED_DIR/${1}.node"; }
track_get()  { cat "$TRACKED_DIR/${1}.node" 2>/dev/null || echo ""; }
track_rm()   { rm -f "$TRACKED_DIR/${1}.node"; }
track_count() { ls "$TRACKED_DIR"/*.node 2>/dev/null | wc -l; }

route_to_sink() {
    local target_id="$1"
    local target_name="$2"
    local eq_id
    eq_id=$(get_eq_out_id)
    [ -z "$eq_id" ] && return 0

    # Unmute in hardware & WirePlumber
    wpctl set-mute "$target_id" 0 2>/dev/null || true

    # Set preferred routing target in metadata
    pw-metadata -n default "$eq_id" target.node "$target_id" 2>/dev/null || true

    # Remove old links from EQ output (skip cava / echo-cancel)
    local old_links
    old_links=$(pw-link -l 2>/dev/null | awk '/effect_output.eq10:output_FL/ {
        while ((getline line) > 0) {
            if (line !~ /^[ |>-]+/) break;
            sub(/^[ |>-]+/, "", line);
            sub(/:playback_FL.*/, "", line);
            if (line !~ /cava|echo[-_]cancel/ && line != "") print line;
        }
    }' || echo "")

    local old
    for old in $old_links; do
        [ "$old" = "$target_name" ] && continue
        pw-link -d effect_output.eq10:output_FL "${old}:playback_FL" 2>/dev/null || true
        pw-link -d effect_output.eq10:output_FR "${old}:playback_FR" 2>/dev/null || true
    done

    # Connect to new target
    pw-link effect_output.eq10:output_FL "${target_name}:playback_FL" 2>/dev/null || true
    pw-link effect_output.eq10:output_FR "${target_name}:playback_FR" 2>/dev/null || true
}

ensure_speaker_fallback() {
    local alsa_id
    alsa_id=$(get_alsa_card_id)
    [ -n "$alsa_id" ] && { wpctl set-profile "$alsa_id" 2 2>/dev/null || true; }

    local spk_info
    spk_info=$(pw-dump Node 2>/dev/null | jq -r '
      .[] | select(.info.props["node.name"] | test("HiFi__Speaker__sink$"))
      | [.id, .info.props["node.name"]] | @tsv
    ' | head -n 1 || echo "")

    [ -z "$spk_info" ] && return 0
    local spk_id spk_name
    IFS=$'\t' read -r spk_id spk_name <<< "$spk_info"
    route_to_sink "$spk_id" "$spk_name"
}

is_external_device() {
    local name="$1" desc="$2" class="$3"
    [[ "$class" =~ ^Audio/(Sink|Source) ]] || return 1
    [[ "$name" =~ ^(effect_|echo[-_]cancel|Dummy|Freewheel|Midi|bluez_midi|v4l2|cava) ]] && return 1
    [[ "$name" =~ HiFi__(Speaker__sink|Mic1__source|Mic2__source) ]] && return 1
    [[ "$name" =~ HiFi__HDMI ]] && return 1
    [[ "$name" =~ HiFi__Headphones__sink ]] && return 0
    [[ "$name" =~ ^bluez_ ]] && return 0
    [[ "$name" =~ usb ]] && return 0
    [[ "$desc" =~ (Bluetooth|Buds|AirPods|Earbuds|Headphone|USB|DAC) ]] && return 0
    return 1
}

clean_name() {
    local desc="$1" name="$2"
    [[ "$name" =~ HiFi__Headphones__sink ]] && { echo "Headphones"; return; }
    [[ "$name" =~ [Hh][Dd][Mm][Ii] ]] && { echo "HDMI Audio"; return; }
    local cleaned
    cleaned=$(echo "$desc" | sed -E 's/\[[^]]*\]//g; s/\([^)]*\)//g; s/[^a-zA-Z0-9 -]/ /g' | awk '{$1=$1};1')
    cleaned=$(echo "$cleaned" | sed -E 's/\b(Wireless|Noise-Canceling|Stereo|Headset|Headphones|Audio)\b//gi' | awk '{$1=$1};1')
    local count
    count=$(echo "$cleaned" | wc -w)
    [ "$count" -gt 2 ] && cleaned=$(echo "$cleaned" | awk '{print $1, $2}')
    if [ -z "$cleaned" ]; then
        [[ "$name" =~ ^bluez_ ]] && cleaned="Bluetooth" || cleaned="Audio Device"
    fi
    echo "$cleaned"
}

handle_connect() {
    local id="$1" name="$2" desc="$3" class="$4"
    is_external_device "$name" "$desc" "$class" || return 0
    [ -n "$(track_get "$id")" ] && return 0  # already tracked

    local dev_name
    dev_name=$(clean_name "$desc" "$name")
    track_add "$id" "$dev_name"

    # Only auto-route for audio output sinks
    [ "$class" = "Audio/Sink" ] || return 0

    route_to_sink "$id" "$name"

    if ! is_manual_cycle && can_notify "${dev_name}_connected"; then
        notify-send -a "Audio" -u low "${dev_name} Connected" 2>/dev/null || true
    fi
}

handle_disconnect() {
    local id="$1"
    local dev_name
    dev_name=$(track_get "$id")
    [ -z "$dev_name" ] && return 0

    track_rm "$id"

    # Pause media on disconnect (like macOS/Windows/iOS)
    playerctl -a pause 2>/dev/null || true

    # Notify
    if ! is_manual_cycle && can_notify "${dev_name}_disconnected"; then
        notify-send -a "Audio" -u low "${dev_name} Disconnected" 2>/dev/null || true
    fi

    # Fallback: if no other external device remains, go to speaker
    if [ "$(track_count)" -eq 0 ]; then
        ensure_speaker_fallback
    fi
}

# Initial priming pass: track already-connected devices, route if any external exists
init_devices() {
    local found_ext=false
    local best_id="" best_name=""

    while IFS=$'\t' read -r id is_null name desc class; do
        [ "$is_null" = "true" ] && continue
        if is_external_device "$name" "$desc" "$class"; then
            local dev_name
            dev_name=$(clean_name "$desc" "$name")
            track_add "$id" "$dev_name"
            if [ "$class" = "Audio/Sink" ] && [ -z "$best_id" ]; then
                best_id="$id"
                best_name="$name"
                found_ext=true
            fi
        elif [[ "$name" =~ HiFi__Speaker__sink$ ]]; then
            # Always ensure speaker is unmuted in hardware
            wpctl set-mute "$id" 0 2>/dev/null || true
        fi
    done < <(pw-dump Node 2>/dev/null | jq -r '
      .[] | [.id, (.info == null | tostring), (.info.props["node.name"] // ""),
             (.info.props["node.description"] // .info.props["node.nick"] // ""),
             (.info.props["media.class"] // "")] | @tsv
    ')

    if [ "$found_ext" = "true" ] && [ -n "$best_id" ]; then
        route_to_sink "$best_id" "$best_name"
    else
        ensure_speaker_fallback
    fi
}

init_devices

# Monitor for changes
pw-dump -N -m Node 2>/dev/null | jq --unbuffered -c -n '
  foreach inputs as $arr (0; . + 1; {
    batch: .,
    items: [ $arr[] | {
      id: .id,
      is_null: (.info == null),
      name: (.info.props["node.name"] // ""),
      desc: (.info.props["node.description"] // .info.props["node.nick"] // ""),
      class: (.info.props["media.class"] // "")
    } ]
  })
' | while IFS= read -r line; do
    batch=$(echo "$line" | jq -r '.batch // 0')
    [ "$batch" -eq 1 ] && continue  # skip first priming dump, already handled

    while IFS=$'\t' read -r id is_null name desc class; do
        if [ "$is_null" = "true" ]; then
            handle_disconnect "$id"
        else
            if [[ "$name" =~ HiFi__Speaker__sink$ ]]; then
                # Speaker sink appeared: unmute and route if no external active
                wpctl set-mute "$id" 0 2>/dev/null || true
                if [ "$(track_count)" -eq 0 ]; then
                    route_to_sink "$id" "$name"
                fi
            else
                handle_connect "$id" "$name" "$desc" "$class"
            fi
        fi
    done < <(echo "$line" | jq -r '.items[] | [.id, (.is_null | tostring), .name, .desc, .class] | @tsv')
done
