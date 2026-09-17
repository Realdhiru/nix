#!/usr/bin/env bash
#
# av_event_stream.sh -- Event-driven volume & brightness broadcaster for Quickshell
# Consumes zero polling cycles: sleeps until kernel udev (backlight) or PipeWire (audio) emits an event.
#
set -u

PIPE="/tmp/qs_av_events_$$.fifo"
rm -f "$PIPE" 2>/dev/null
mkfifo "$PIPE" 2>/dev/null

trap 'rm -f "$PIPE"; pkill -P $$ 2>/dev/null; exit 0' EXIT INT TERM

emit_state() {
    raw_vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.0")
    muted=0
    [[ "$raw_vol" == *"[MUTED]"* ]] && muted=1
    vol_val="${raw_vol#*: }"
    vol_val="${vol_val%% *}"
    vol_pct=$(awk -v v="$vol_val" 'BEGIN { printf "%d", (v * 100 + 0.5) }')

    bri_pct=$(brightnessctl -m 2>/dev/null | cut -d',' -f4 | tr -d '%')
    [ -z "$bri_pct" ] && bri_pct=0

    echo "${vol_pct}|${muted}|${bri_pct}"
}

# Emit initial state immediately on startup
emit_state

# Event sources: stream into FIFO
udevadm monitor --subsystem-match=backlight 2>/dev/null > "$PIPE" &
pw-mon 2>/dev/null | grep --line-buffered -E "Props:volume|Props:mute" > "$PIPE" &

# Read events with 50ms anti-burst debounce
while read -r _; do
    while read -t 0.05 -r _; do :; done
    emit_state
done < "$PIPE"
