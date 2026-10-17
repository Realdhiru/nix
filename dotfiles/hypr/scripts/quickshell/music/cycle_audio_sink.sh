#!/usr/bin/env bash
# Fast PipeWire audio sink cycler (pure bash + pw-link + wpctl)

mapfile -t sinks < <(pw-link -i 2>/dev/null | grep ':playback_FL' | grep -v 'effect_input' | sed 's/:playback_FL//')

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

# Also set physical default in wireplumber if node id is found
target_id=$(pw-cli ls Node 2>/dev/null | awk -v name="$next_target" '/id [0-9]+/ {id=$2} $0 ~ name {gsub(/,/, "", id); print id; exit}')
if [ -n "$target_id" ]; then
    wpctl set-default "$target_id" 2>/dev/null || true
fi
