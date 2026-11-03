#!/usr/bin/env bash
# karaoke [on|off|toggle]
set -euo pipefail
state_file="${XDG_RUNTIME_DIR:-/tmp}/karaoke.state"
id=$(pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["node.name"]=="effect_input.karaoke") | .id')
[ -n "$id" ] || { echo "effect_input.karaoke not found" >&2; exit 1; }
cur=$(cat "$state_file" 2>/dev/null || echo off)
case "${1:-toggle}" in
  on|off) target=$1 ;;
  toggle) [ "$cur" = on ] && target=off || target=on ;;
  *) echo "usage: $0 [on|off|toggle]" >&2; exit 2 ;;
esac
set_mix() {
  pw-cli s "$id" Props "{ params = [ \"finalL:Gain 1\" $1 \"finalL:Gain 2\" $2 \"finalR:Gain 1\" $1 \"finalR:Gain 2\" $2 ] }" >/dev/null
}
for i in 1 2 3 4 5 6; do
  k=$(awk -v i="$i" 'BEGIN{printf "%.3f", i/6}')
  r=$(awk -v k="$k" 'BEGIN{printf "%.3f", 1-k}')
  if [ "$target" = on ]; then set_mix "$r" "$k"; else set_mix "$k" "$r"; fi
done
echo "$target" > "$state_file"
