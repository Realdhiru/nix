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
      # g=0.7, bl=1.0, ha=1.0, ks=1.0, G=1.8, LP=120Hz, HP=6000Hz
      # mp: Gain 1=0.3, Gain 2=0.7, Gain 3=0.7; karL/R: Gain 1=1.8, Gain 2=+/-1.8
      pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 120.0 \"lp2:Freq\" 120.0 \"hp1:Freq\" 6000.0 \"hp2:Freq\" 6000.0 \"mp:Gain 1\" 0.3 \"mp:Gain 2\" 0.7 \"mp:Gain 3\" 0.7 \"karL:Gain 1\" 1.8 \"karL:Gain 2\" 1.8 \"karR:Gain 1\" 1.8 \"karR:Gain 2\" -1.8 ] }" >/dev/null 2>&1 || true
      ;;
    "Hard")
      # g=1.0, bl=1.0, ha=1.0, ks=1.0, G=2.2, LP=200Hz, HP=8000Hz
      # mp: Gain 1=0.0, Gain 2=1.0, Gain 3=1.0; karL/R: Gain 1=2.2, Gain 2=+/-2.2
      pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 200.0 \"lp2:Freq\" 200.0 \"hp1:Freq\" 8000.0 \"hp2:Freq\" 8000.0 \"mp:Gain 1\" 0.0 \"mp:Gain 2\" 1.0 \"mp:Gain 3\" 1.0 \"karL:Gain 1\" 2.2 \"karL:Gain 2\" 2.2 \"karR:Gain 1\" 2.2 \"karR:Gain 2\" -2.2 ] }" >/dev/null 2>&1 || true
      ;;
    "Standard"|*)
      # g=0.9, bl=1.0, ha=1.0, ks=1.0, G=1.8, LP=150Hz, HP=7000Hz
      # mp: Gain 1=0.1, Gain 2=0.9, Gain 3=0.9; karL/R: Gain 1=1.8, Gain 2=+/-1.8
      pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 150.0 \"lp2:Freq\" 150.0 \"hp1:Freq\" 7000.0 \"hp2:Freq\" 7000.0 \"mp:Gain 1\" 0.1 \"mp:Gain 2\" 0.9 \"mp:Gain 3\" 0.9 \"karL:Gain 1\" 1.8 \"karL:Gain 2\" 1.8 \"karR:Gain 1\" 1.8 \"karR:Gain 2\" -1.8 ] }" >/dev/null 2>&1 || true
      ;;
  esac
}

case "$preset" in
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
