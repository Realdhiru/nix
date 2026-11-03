#!/usr/bin/env bash
# karaoke [on|off|toggle|Gentle|Standard|Hard]
set -euo pipefail
id=$(pw-dump 2>/dev/null | jq -r '.[] | select(.info.props["node.name"]=="effect_input.karaoke") | .id')
[ -n "$id" ] || { echo "effect_input.karaoke not found" >&2; exit 0; }

preset="${1:-Standard}"

set_mix() {
  pw-cli s "$id" Props "{ params = [ \"finalL:Gain 1\" $1 \"finalL:Gain 2\" $2 \"finalR:Gain 1\" $1 \"finalR:Gain 2\" $2 ] }" >/dev/null 2>&1 || true
}

apply_preset_params() {
  case "$1" in
    "Gentle")
      # g=0.70, bl=1.0, ha=1.0, ks=1.0, G=1.97 (median measured), LP=120Hz, HP=6000Hz
      # mp: Gain 1=0.30, Gain 2=0.70, Gain 3=0.70; karL/R: Gain 1=1.97, Gain 2=+/-1.97
      pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 120.0 \"lp2:Freq\" 120.0 \"hp1:Freq\" 6000.0 \"hp2:Freq\" 6000.0 \"mp:Gain 1\" 0.30 \"mp:Gain 2\" 0.70 \"mp:Gain 3\" 0.70 \"karL:Gain 1\" 1.97 \"karL:Gain 2\" 1.97 \"karR:Gain 1\" 1.97 \"karR:Gain 2\" -1.97 ] }" >/dev/null 2>&1 || true
      ;;
    "Hard")
      # g=0.95 (capped to prevent anti-phase cancel), bl=1.0, ha=1.0, ks=1.0, G=1.43 (median measured), LP=200Hz, HP=8000Hz
      # mp: Gain 1=0.05, Gain 2=0.95, Gain 3=0.95; karL/R: Gain 1=1.43, Gain 2=+/-1.43
      pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 200.0 \"lp2:Freq\" 200.0 \"hp1:Freq\" 8000.0 \"hp2:Freq\" 8000.0 \"mp:Gain 1\" 0.05 \"mp:Gain 2\" 0.95 \"mp:Gain 3\" 0.95 \"karL:Gain 1\" 1.43 \"karL:Gain 2\" 1.43 \"karR:Gain 1\" 1.43 \"karR:Gain 2\" -1.43 ] }" >/dev/null 2>&1 || true
      ;;
    "Standard"|*)
      # g=0.90, bl=1.0, ha=1.0, ks=1.0, G=1.74 (median measured), LP=150Hz, HP=7000Hz
      # mp: Gain 1=0.10, Gain 2=0.90, Gain 3=0.90; karL/R: Gain 1=1.74, Gain 2=+/-1.74
      pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 150.0 \"lp2:Freq\" 150.0 \"hp1:Freq\" 7000.0 \"hp2:Freq\" 7000.0 \"mp:Gain 1\" 0.10 \"mp:Gain 2\" 0.90 \"mp:Gain 3\" 0.90 \"karL:Gain 1\" 1.74 \"karL:Gain 2\" 1.74 \"karR:Gain 1\" 1.74 \"karR:Gain 2\" -1.74 ] }" >/dev/null 2>&1 || true
      ;;
  esac
}

case "$preset" in
  trim)
    # Live trim in dB (+N or -N), read current value via pw-dump, no state files
    delta_db="${2:-0}"
    # Read current karL:Gain 1
    cur_g=$(pw-dump 2>/dev/null | jq -r --arg id "$id" '.[] | select(.id == ($id|tonumber)) | .info.params.Props[0].params // empty | .[]? // empty' 2>/dev/null | grep -A 1 '"karL:Gain 1"' | tail -n 1 || echo "1.74")
    [ -n "$cur_g" ] || cur_g="1.74"
    new_g=$(awk -v g="$cur_g" -v db="$delta_db" 'BEGIN { factor = 10^(db/20); res = g * factor; if (res < 0.1) res = 0.1; if (res > 5.0) res = 5.0; printf "%.3f", res }')
    pw-cli s "$id" Props "{ params = [ \"karL:Gain 1\" $new_g \"karL:Gain 2\" $new_g \"karR:Gain 1\" $new_g \"karR:Gain 2\" -$new_g ] }" >/dev/null 2>&1 || true
    echo "Karaoke gain trimmed by ${delta_db} dB: ${cur_g} -> ${new_g}"
    ;;
  off)
    for i in 1 2 3 4 5 6; do
      k=$(awk -v i="$i" 'BEGIN{printf "%.3f", i/6}')
      r=$(awk -v k="$k" 'BEGIN{printf "%.3f", 1-k}')
      set_mix "$k" "$r"
    done
    ;;
  on|"Gentle"|"Standard"|"Hard")
    apply_preset_params "$preset"
    for i in 1 2 3 4 5 6; do
      k=$(awk -v i="$i" 'BEGIN{printf "%.3f", i/6}')
      r=$(awk -v k="$k" 'BEGIN{printf "%.3f", 1-k}')
      set_mix "$r" "$k"
    done
    ;;
  *)
    exit 0
    ;;
esac
