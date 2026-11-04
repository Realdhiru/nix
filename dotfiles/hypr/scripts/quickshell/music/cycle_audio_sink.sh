#!/usr/bin/env bash
# Fast PipeWire audio sink cycler (pure bash + pw-link + wpctl)

has_hdmi=false
if grep -q "^connected" /sys/class/drm/card*-HDMI*/status 2>/dev/null; then
    has_hdmi=true
fi

raw_sinks=$(pw-link -i 2>/dev/null | grep ':playback_FL' | grep -v 'effect_input' || true)
sinks=()
while IFS= read -r line; do
    [ -z "$line" ] && continue
    node="${line%:playback_FL}"
    if [[ "$node" == *"HiFi__HDMI"* ]] && [ "$has_hdmi" = false ]; then
        continue
    fi
    sinks+=("$node")
done <<< "$raw_sinks"

if [ "${#sinks[@]}" -le 1 ]; then
    exit 0
fi

cur_target=$(pw-link -l 2>/dev/null | awk '/effect_output.eq10:output_FL/ {getline; sub(/^[ |>-]+/, ""); sub(/:playback_FL.*/, ""); print; exit}')

cur_idx=0
for i in "${!sinks[@]}"; do
    if [ "${sinks[$i]}" = "$cur_target" ]; then
        cur_idx=$i
        break
    fi
done

next_idx=$(( (cur_idx + 1) % ${#sinks[@]} ))
next_target="${sinks[$next_idx]}"

if [ -n "$cur_target" ]; then
    pw-link -d effect_output.eq10:output_FL "${cur_target}:playback_FL" 2>/dev/null || true
    pw-link -d effect_output.eq10:output_FR "${cur_target}:playback_FR" 2>/dev/null || true
fi

pw-link effect_output.eq10:output_FL "${next_target}:playback_FL" 2>/dev/null || true
pw-link effect_output.eq10:output_FR "${next_target}:playback_FR" 2>/dev/null || true
