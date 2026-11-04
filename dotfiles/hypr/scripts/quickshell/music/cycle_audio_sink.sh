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
      (.info.props["node.name"] | startswith("effect_input") | not) and
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

# Find currently linked sink
cur_target_name=$(pw-link -l 2>/dev/null | awk '/effect_output.eq10:output_FL/ {getline; sub(/^[ |>-]+/, ""); sub(/:playback_FL.*/, ""); print; exit}' || echo "")

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

# If no external Bluetooth/USB audio devices are connected
if [ "$num_ext" -eq 0 ]; then
    if [[ "$cur_target_name" == *"Headphone"* ]]; then
        switch_to_profile 2 "Speaker" "Laptop Speaker"
    else
        switch_to_profile 1 "Headphones" "Wired Headphones"
    fi
    exit 0
fi

# External Bluetooth / USB sink is connected: cycle Speaker -> Headphones -> Bluetooth/USB
if [[ "$cur_target_name" == *"Speaker"* ]]; then
    switch_to_profile 1 "Headphones" "Wired Headphones"
elif [[ "$cur_target_name" == *"Headphone"* ]]; then
    first_ext=$(echo "$ext_sinks" | jq -c '.[0]')
    ext_id=$(echo "$first_ext" | jq -r '.id')
    ext_name=$(echo "$first_ext" | jq -r '.name')
    ext_desc=$(echo "$first_ext" | jq -r '.desc')
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/audio"
    mkdir -p "$state_dir"
    date +%s > "$state_dir/manual_cycle_ts"

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
