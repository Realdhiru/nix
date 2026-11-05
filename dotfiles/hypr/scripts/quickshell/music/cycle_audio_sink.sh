#!/usr/bin/env bash
# Robust audio output switcher (Speaker <-> Wired Headphones <-> Bluetooth / USB)
set -euo pipefail

EQ_OUT_ID=$(pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_output.eq10"/ {gsub(/,/, "", id); print id; exit}' || echo "")
if [ -z "$EQ_OUT_ID" ]; then
    notify-send -a "Audio" -u low "Equalizer Offline" 2>/dev/null || true
    exit 0
fi

ALSA_CARD_ID=$(pw-cli ls Device 2>/dev/null | awk '/id [0-9]+/ {id=$2} /device.name = "alsa_card.*platform-skl_hda_dsp/ {gsub(/,/, "", id); print id; exit}' || echo "")

has_hdmi=false
if grep -q "^connected" /sys/class/drm/card*-HDMI*/status 2>/dev/null; then
    has_hdmi=true
fi

# Discover external sinks (Bluetooth / USB) from PipeWire
ext_sinks=$(pw-dump Node 2>/dev/null | jq -c --arg has_hdmi "$has_hdmi" '
  [ .[] | select(
      .info.props["media.class"] == "Audio/Sink" and
      (.info.props["node.name"] | test("effect_input|cava|echo"; "i") | not) and
      (($has_hdmi == "true") or (.info.props["node.name"] | test("HiFi__HDMI") | not)) and
      (
        (.info.props["node.name"] | test("bluez|usb"; "i")) or
        ((.info.props["node.description"] // "") | test("Bluetooth|Buds|AirPods|Earbuds|USB Audio"; "i"))
      )
    ) | {
      id: .id,
      name: .info.props["node.name"],
      desc: (.info.props["node.description"] // .info.props["node.name"])
    }
  ]
')

# Find currently linked sink (skipping visualizers like cava)
cur_target_name=$(pw-link -l 2>/dev/null | awk '/effect_output.eq10:output_FL/ {
    while ((getline line) > 0) {
        if (line !~ /^[ |>-]+/) break;
        sub(/^[ |>-]+/, "", line);
        sub(/:playback_FL.*/, "", line);
        if (line !~ /cava|echo[-_]cancel/ && line != "") {
            print line;
            exit;
        }
    }
}' || echo "")

num_ext=$(echo "$ext_sinks" | jq 'length')

switch_to_profile() {
    local prof_idx="$1"
    local prof_name="$2"
    local desc="$3"

    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/audio"
    mkdir -p "$state_dir"
    date +%s > "$state_dir/manual_cycle_ts"

    if [ -n "$ALSA_CARD_ID" ]; then
        wpctl set-profile "$ALSA_CARD_ID" "$prof_idx" 2>/dev/null || true
    fi

    local target_node="alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__${prof_name}__sink"
    local new_sink
    new_sink=$(pw-cli ls Node 2>/dev/null | awk -v pat="node.name = \"${target_node}\"" '/id [0-9]+/ {id=$2} $0 ~ pat {gsub(/,/, "", id); print id; exit}' || echo "")

    if [ -n "$new_sink" ]; then
        wpctl set-mute "$new_sink" 0 2>/dev/null || true
        pw-metadata -n default "$EQ_OUT_ID" target.node "$new_sink" 2>/dev/null || true
    fi

    if [ -n "$cur_target_name" ] && [ "$cur_target_name" != "$target_node" ]; then
        pw-link -d effect_output.eq10:output_FL "${cur_target_name}:playback_FL" 2>/dev/null || true
        pw-link -d effect_output.eq10:output_FR "${cur_target_name}:playback_FR" 2>/dev/null || true
    fi

    pw-link effect_output.eq10:output_FL "${target_node}:playback_FL" 2>/dev/null || true
    pw-link effect_output.eq10:output_FR "${target_node}:playback_FR" 2>/dev/null || true

    notify-send -a "Audio" -t 1500 -u low "$desc" 2>/dev/null || true
}

# Check if 3.5mm wired headphones are physically plugged in
jack_connected=false
if [ -n "$ALSA_CARD_ID" ]; then
    jack_avail=$(pw-dump Device 2>/dev/null | jq -r '
      [ .[] | select(.info.props["device.name"] | test("alsa_card")) | .info.params.Route[]? | select(.name == "[Out] Headphones") | .available ] | .[0] // "unknown"
    ')
    [ "$jack_avail" = "yes" ] && jack_connected=true
fi

# Build list of cycle candidates in priority order: Speaker, Headphones (if plugged), External Sinks (Bluetooth, USB)
# Decision tree based on currently linked endpoint
if [ "$num_ext" -gt 0 ]; then
    first_ext=$(echo "$ext_sinks" | jq -c '.[0]')
    ext_id=$(echo "$first_ext" | jq -r '.id')
    ext_name=$(echo "$first_ext" | jq -r '.name')
    ext_desc=$(echo "$first_ext" | jq -r '.desc')

    if [[ "$cur_target_name" == *"Speaker"* ]]; then
        if [ "$jack_connected" = "true" ]; then
            switch_to_profile 1 "Headphones" "Headphones"
        else
            # Directly switch to external bluetooth/usb device
            state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/audio"
            mkdir -p "$state_dir"
            date +%s > "$state_dir/manual_cycle_ts"

            wpctl set-mute "$ext_id" 0 2>/dev/null || true
            pw-metadata -n default "$EQ_OUT_ID" target.node "$ext_id" 2>/dev/null || true
            if [ -n "$cur_target_name" ] && [ "$cur_target_name" != "$ext_name" ]; then
                pw-link -d effect_output.eq10:output_FL "${cur_target_name}:playback_FL" 2>/dev/null || true
                pw-link -d effect_output.eq10:output_FR "${cur_target_name}:playback_FR" 2>/dev/null || true
            fi
            pw-link effect_output.eq10:output_FL "${ext_name}:playback_FL" 2>/dev/null || true
            pw-link effect_output.eq10:output_FR "${ext_name}:playback_FR" 2>/dev/null || true
            notify-send -a "Audio" -t 1500 -u low "$ext_desc" 2>/dev/null || true
        fi
    elif [[ "$cur_target_name" == *"Headphone"* ]]; then
        state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/audio"
        mkdir -p "$state_dir"
        date +%s > "$state_dir/manual_cycle_ts"

        wpctl set-mute "$ext_id" 0 2>/dev/null || true
        pw-metadata -n default "$EQ_OUT_ID" target.node "$ext_id" 2>/dev/null || true
        if [ -n "$cur_target_name" ] && [ "$cur_target_name" != "$ext_name" ]; then
            pw-link -d effect_output.eq10:output_FL "${cur_target_name}:playback_FL" 2>/dev/null || true
            pw-link -d effect_output.eq10:output_FR "${cur_target_name}:playback_FR" 2>/dev/null || true
        fi
        pw-link effect_output.eq10:output_FL "${ext_name}:playback_FL" 2>/dev/null || true
        pw-link effect_output.eq10:output_FR "${ext_name}:playback_FR" 2>/dev/null || true
        notify-send -a "Audio" -t 1500 -u low "$ext_desc" 2>/dev/null || true
    else
        switch_to_profile 2 "Speaker" "Laptop Speaker"
    fi
else
    # No external Bluetooth/USB: cycle between Speaker and Headphones (if connected or manual toggle)
    if [[ "$cur_target_name" == *"Headphone"* ]]; then
        switch_to_profile 2 "Speaker" "Laptop Speaker"
    else
        switch_to_profile 1 "Headphones" "Headphones"
    fi
fi
