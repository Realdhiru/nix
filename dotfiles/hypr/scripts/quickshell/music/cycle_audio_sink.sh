#!/usr/bin/env bash
# Robust audio output switcher (Speaker <-> Bluetooth / Headphones)
set -euo pipefail

if [ -z "$EQ_OUT_ID" ]; then
    notify-send -a "Audio" -u low "Equalizer Offline" 2>/dev/null || true
    exit 0
fi

has_hdmi=false
if grep -q "^connected" /sys/class/drm/card*-HDMI*/status 2>/dev/null; then
    has_hdmi=true
fi

# Discover all physical audio sinks from PipeWire
all_sinks=$(pw-dump Node 2>/dev/null | jq -c --arg has_hdmi "$has_hdmi" '
  [ .[] | select(
      .info.props["media.class"] == "Audio/Sink" and
      (.info.props["node.name"] | startswith("effect_input") | not) and
      (($has_hdmi == "true") or (.info.props["node.name"] | test("HiFi__HDMI") | not))
    ) | {
      id: .id,
      name: .info.props["node.name"],
      desc: (.info.props["node.description"] // .info.props["node.name"]),
      is_external: (
        (.info.props["node.name"] | test("bluez|Headphone|headset|usb"; "i")) or
        ((.info.props["node.description"] // "") | test("Bluetooth|Headphone|Headset|Buds|AirPods|Earbuds"; "i"))
      )
    }
  ]
')

num_sinks=$(echo "$all_sinks" | jq 'length')
if [ "$num_sinks" -le 1 ]; then
    notify-send -a "Audio" -t 1500 -u low "Laptop Speaker" 2>/dev/null || true
    exit 0
fi

# Find currently linked sink
cur_target_name=$(pw-link -l 2>/dev/null | awk '/effect_output.eq10:output_FL/ {getline; sub(/^[ |>-]+/, ""); sub(/:playback_FL.*/, ""); print; exit}' || echo "")

ext_sink=$(echo "$all_sinks" | jq -c '[ .[] | select(.is_external == true) ] | .[0] // empty')
speaker_sink=$(echo "$all_sinks" | jq -c '[ .[] | select(.is_external == false) ] | .[0] // empty')

target_sink=""

if [ -n "$ext_sink" ] && [ -n "$speaker_sink" ]; then
    cur_is_ext=$(echo "$ext_sink" | jq -r --arg name "$cur_target_name" 'if .name == $name then "true" else "false" end')
    if [ "$cur_is_ext" = "true" ]; then
        target_sink="$speaker_sink"
    else
        target_sink="$ext_sink"
    fi
else
    cur_idx=$(echo "$all_sinks" | jq -r --arg name "$cur_target_name" 'map(.name == $name) | index(true) // 0')
    next_idx=$(( (cur_idx + 1) % num_sinks ))
    target_sink=$(echo "$all_sinks" | jq -c ".[$next_idx]")
fi

next_id=$(echo "$target_sink" | jq -r '.id')
next_name=$(echo "$target_sink" | jq -r '.name')
next_desc=$(echo "$target_sink" | jq -r '.desc')

if [[ "$next_name" == *"Speaker"* ]]; then
    display_desc="Laptop Speaker"
else
    display_desc="$next_desc"
fi

# 1. Update PipeWire metadata so WirePlumber manages and respects target routing
pw-metadata -n default "$EQ_OUT_ID" target.node "$next_id" 2>/dev/null || true

# 2. Re-link audio ports immediately
if [ -n "$cur_target_name" ] && [ "$cur_target_name" != "$next_name" ]; then
    pw-link -d effect_output.eq10:output_FL "${cur_target_name}:playback_FL" 2>/dev/null || true
    pw-link -d effect_output.eq10:output_FR "${cur_target_name}:playback_FR" 2>/dev/null || true
fi

pw-link effect_output.eq10:output_FL "${next_name}:playback_FL" 2>/dev/null || true
pw-link effect_output.eq10:output_FR "${next_name}:playback_FR" 2>/dev/null || true


# 4. Notify user
notify-send -a "Audio" -t 1500 -u low "$display_desc" 2>/dev/null || true
