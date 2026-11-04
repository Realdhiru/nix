#!/usr/bin/env bash
# karaoke [on|off|toggle|Gentle|Standard|Hard|Max]
set -eu

id=$(timeout 2 pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_input.karaoke"/ {gsub(/,/, "", id); print id; exit}' || true)
[ -n "$id" ] || { echo "effect_input.karaoke not found" >&2; exit 0; }

preset="${1:-Standard}"

set_mix() {
  timeout 2 pw-cli s "$id" Props "{ params = [ \"finalL:Gain 1\" $1 \"finalL:Gain 2\" $2 \"finalR:Gain 1\" $1 \"finalR:Gain 2\" $2 ] }" >/dev/null 2>&1 || true
}

apply_preset_params() {
  case "$1" in
    "Gentle"|"Light")
      # g=0.80, bl=1.0, ha=1.0, ks=1.0, LP=120Hz, HP=6000Hz
      timeout 2 pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 120.0 \"lp2:Freq\" 120.0 \"hp1:Freq\" 6000.0 \"hp2:Freq\" 6000.0 \"mp:Gain 1\" 0.20 \"mp:Gain 2\" 0.80 \"mp:Gain 3\" 0.80 \"karL_raw:Gain 1\" 1.0 \"karL_raw:Gain 2\" 1.0 \"karR_raw:Gain 1\" 1.0 \"karR_raw:Gain 2\" -1.0 ] }" >/dev/null 2>&1 || true
      ;;
    "Hard")
      # g=0.95 (capped to prevent anti-phase cancel), bl=1.0, ha=1.0, ks=1.0, LP=200Hz, HP=8000Hz
      timeout 2 pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 200.0 \"lp2:Freq\" 200.0 \"hp1:Freq\" 8000.0 \"hp2:Freq\" 8000.0 \"mp:Gain 1\" 0.05 \"mp:Gain 2\" 0.95 \"mp:Gain 3\" 0.95 \"karL_raw:Gain 1\" 1.0 \"karL_raw:Gain 2\" 1.0 \"karR_raw:Gain 1\" 1.0 \"karR_raw:Gain 2\" -1.0 ] }" >/dev/null 2>&1 || true
      ;;
    "Max"|"Max vocal"|"MaxVocal")
      # g=0.96 (-28 dB center cut across 100Hz-8500Hz full vocal band), bl=1.0, ha=1.0, ks=1.0, LP=100Hz, HP=8500Hz
      timeout 2 pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 100.0 \"lp2:Freq\" 100.0 \"hp1:Freq\" 8500.0 \"hp2:Freq\" 8500.0 \"mp:Gain 1\" 0.04 \"mp:Gain 2\" 0.96 \"mp:Gain 3\" 0.96 \"karL_raw:Gain 1\" 1.0 \"karL_raw:Gain 2\" 1.0 \"karR_raw:Gain 1\" 1.0 \"karR_raw:Gain 2\" -1.0 ] }" >/dev/null 2>&1 || true
      ;;
    "Standard"|*)
      # g=0.90, bl=1.0, ha=1.0, ks=1.0, LP=150Hz, HP=7000Hz
      timeout 2 pw-cli s "$id" Props "{ params = [ \"lp1:Freq\" 150.0 \"lp2:Freq\" 150.0 \"hp1:Freq\" 7000.0 \"hp2:Freq\" 7000.0 \"mp:Gain 1\" 0.10 \"mp:Gain 2\" 0.90 \"mp:Gain 3\" 0.90 \"karL_raw:Gain 1\" 1.0 \"karL_raw:Gain 2\" 1.0 \"karR_raw:Gain 1\" 1.0 \"karR_raw:Gain 2\" -1.0 ] }" >/dev/null 2>&1 || true
      ;;
  esac
}

case "$preset" in
  toggle)
    def_sink=$(timeout 2 wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '/id [0-9]+/ {print $2; exit}' || echo "")
    if [ "$def_sink" = "$id," ] || [ "$def_sink" = "$id" ]; then
      "$0" off
    else
      "$0" Standard
    fi
    ;;
  trim)
    delta_db="${2:-0}"
    cur_allowance=$(timeout 2 pw-dump "$id" 2>/dev/null | jq -r '.[].info.params.Props[]?.params[]? // empty' 2>/dev/null | grep -A 1 '^addAllowance:Add$' | tail -n 1 || echo "-0.5")
    [ -n "$cur_allowance" ] || cur_allowance="-0.5"
    new_allowance=$(awk -v a="$cur_allowance" -v d="$delta_db" 'BEGIN { res = a + d; if (res < -12.0) res = -12.0; if (res > 6.0) res = 6.0; printf "%.2f", res }')
    timeout 2 pw-cli s "$id" Props "{ params = [ \"addAllowance:Add\" $new_allowance ] }" >/dev/null 2>&1 || true
    echo "Karaoke adaptive allowance trimmed by ${delta_db} dB: ${cur_allowance} -> ${new_allowance} LU"
    ;;
  off)
    set_mix 1.0 0.0
    def_sink=$(timeout 1 wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '/id [0-9]+/ {print $2; exit}' | tr -d ',' || echo "")
    eq_id=$(timeout 1 pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_input.eq10"/ {gsub(/,/, "", id); print id; exit}' || true)
    if [ -n "$eq_id" ] && [ "$def_sink" != "$eq_id" ]; then
      timeout 2 wpctl set-default "$eq_id" 2>/dev/null || true
    fi
    ;;
  on|"Gentle"|"Light"|"Standard"|"Hard"|"Max"|"Max vocal"|"MaxVocal")
    apply_preset_params "$preset"
    set_mix 0.0 1.0
    def_sink=$(timeout 1 wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '/id [0-9]+/ {print $2; exit}' | tr -d ',' || echo "")
    if [ -n "$id" ] && [ "$def_sink" != "$id" ]; then
      timeout 2 wpctl set-default "$id" 2>/dev/null || true
    fi
    ;;
  *)
    exit 0
    ;;
esac
