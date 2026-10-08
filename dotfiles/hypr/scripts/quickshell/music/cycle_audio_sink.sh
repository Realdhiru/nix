#!/usr/bin/env bash
# Fast PipeWire audio sink cycler (pure bash + wpctl)
sinks=()
cur_idx=0
idx=0

while read -r line; do
    [ -z "$line" ] && continue
    is_cur=0
    [[ "$line" == \** ]] && is_cur=1
    num=$(echo "$line" | grep -o -E '[0-9]+' | head -n 1)
    if [ -n "$num" ]; then
        sinks+=("$num")
        [ "$is_cur" -eq 1 ] && cur_idx=$idx
        idx=$((idx + 1))
    fi
done < <(wpctl status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p' | grep -E '[0-9]+\.' | sed -E 's/^[│ ]*//')

if [ "${#sinks[@]}" -gt 0 ]; then
    next_idx=$(( (cur_idx + 1) % ${#sinks[@]} ))
    next_id="${sinks[$next_idx]}"
    wpctl set-default "$next_id" 2>/dev/null || true
fi
