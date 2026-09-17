#!/usr/bin/env bash
set -u

raw_vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.0")
muted=0
[[ "$raw_vol" == *"[MUTED]"* ]] && muted=1
vol_val="${raw_vol#*: }"
vol_val="${vol_val%% *}"
vol_pct=$(awk -v v="$vol_val" 'BEGIN { printf "%d", (v * 100 + 0.5) }')

bri_pct=$(brightnessctl -m 2>/dev/null | cut -d',' -f4 | tr -d '%')
[ -z "$bri_pct" ] && bri_pct=0

echo "${vol_pct}|${muted}|${bri_pct}"
