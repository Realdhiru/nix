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
    "Gentle"|"Light")
      # g=0.80, bl=1.0, ha=1.0, ks=1.0, LP=120Hz, HP=6000Hz
      # mp: Gain 1=0.20, Gain 2=0.80, Gain 3=0.80; unity matrix karL_raw / karR_raw
      pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 120.0 \"lp2:Freq\" 120.0 \"hp1:Freq\" 6000.0 \"hp2:Freq\" 6000.0 \"mp:Gain 1\" 0.20 \"mp:Gain 2\" 0.80 \"mp:Gain 3\" 0.80 \"karL_raw:Gain 1\" 1.0 \"karL_raw:Gain 2\" 1.0 \"karR_raw:Gain 1\" 1.0 \"karR_raw:Gain 2\" -1.0 ] }" >/dev/null 2>&1 || true
      ;;
    "Hard")
      # g=0.95 (capped to prevent anti-phase cancel), bl=1.0, ha=1.0, ks=1.0, LP=200Hz, HP=8000Hz
      # mp: Gain 1=0.05, Gain 2=0.95, Gain 3=0.95; unity matrix karL_raw / karR_raw
      pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 200.0 \"lp2:Freq\" 200.0 \"hp1:Freq\" 8000.0 \"hp2:Freq\" 8000.0 \"mp:Gain 1\" 0.05 \"mp:Gain 2\" 0.95 \"mp:Gain 3\" 0.95 \"karL_raw:Gain 1\" 1.0 \"karL_raw:Gain 2\" 1.0 \"karR_raw:Gain 1\" 1.0 \"karR_raw:Gain 2\" -1.0 ] }" >/dev/null 2>&1 || true
      ;;
    "Max"|"Max vocal"|"MaxVocal")
      # g=0.96 (-28 dB center cut across 300Hz-4500Hz), bl=1.0, ha=1.0, ks=1.0, LP=300Hz, HP=4500Hz
      # mp: Gain 1=0.04, Gain 2=0.96, Gain 3=0.96; unity matrix karL_raw / karR_raw
      pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 300.0 \"lp2:Freq\" 300.0 \"hp1:Freq\" 4500.0 \"hp2:Freq\" 4500.0 \"mp:Gain 1\" 0.04 \"mp:Gain 2\" 0.96 \"mp:Gain 3\" 0.96 \"karL_raw:Gain 1\" 1.0 \"karL_raw:Gain 2\" 1.0 \"karR_raw:Gain 1\" 1.0 \"karR_raw:Gain 2\" -1.0 ] }" >/dev/null 2>&1 || true
      ;;
    "Standard"|*)
      # g=0.90, bl=1.0, ha=1.0, ks=1.0, LP=150Hz, HP=7000Hz
      # mp: Gain 1=0.10, Gain 2=0.90, Gain 3=0.90; unity matrix karL_raw / karR_raw
      pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 150.0 \"lp2:Freq\" 150.0 \"hp1:Freq\" 7000.0 \"hp2:Freq\" 7000.0 \"mp:Gain 1\" 0.10 \"mp:Gain 2\" 0.90 \"mp:Gain 3\" 0.90 \"karL_raw:Gain 1\" 1.0 \"karL_raw:Gain 2\" 1.0 \"karR_raw:Gain 1\" 1.0 \"karR_raw:Gain 2\" -1.0 ] }" >/dev/null 2>&1 || true
      ;;
  esac
}

case "$preset" in
  trim)
    # Live trim in LU / dB (+N or -N), adjusts addAllowance:Add directly in PipeWire node props without state files
    delta_db="${2:-0}"
    cur_allowance=$(pw-dump "$id" 2>/dev/null | jq -r '.[].info.params.Props[]?.params[]? // empty' 2>/dev/null | grep -A 1 '^addAllowance:Add$' | tail -n 1 || echo "-0.5")
    [ -n "$cur_allowance" ] || cur_allowance="-0.5"
    new_allowance=$(awk -v a="$cur_allowance" -v d="$delta_db" 'BEGIN { res = a + d; if (res < -12.0) res = -12.0; if (res > 6.0) res = 6.0; printf "%.2f", res }')
    pw-cli s "$id" Props "{ params = [ \"addAllowance:Add\" $new_allowance ] }" >/dev/null 2>&1 || true
    echo "Karaoke adaptive allowance trimmed by ${delta_db} dB: ${cur_allowance} -> ${new_allowance} LU"
    ;;
  off)
    for i in 1 2 3 4 5 6; do
      k=$(awk -v i="$i" 'BEGIN{printf "%.3f", i/6}')
      r=$(awk -v k="$k" 'BEGIN{printf "%.3f", 1-k}')
      set_mix "$k" "$r"
    done
    ;;
  on|"Gentle"|"Light"|"Standard"|"Hard"|"Max"|"Max vocal"|"MaxVocal")
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
