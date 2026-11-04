#!/usr/bin/env bash
# karaoke [on|off|toggle|Gentle|Standard|Hard|Max|trim]
set -eu

exec 201>"${XDG_RUNTIME_DIR:-/run/user/1000}/karaoke.lock"
flock 201

id=$(timeout 2 pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_input.eq10"/ {gsub(/,/, "", id); print id; exit}' || true)
if [ -z "$id" ]; then
    notify-send -a "Karaoke" -u low "Equalizer Offline" 2>/dev/null || true
    echo "effect_input.eq10 not found" >&2
    exit 0
fi

preset="${1:-Standard}"

set_mix() {
  timeout 2 pw-cli s "$id" Props "{ params = [ \"finalL:Gain 1\" $1 \"finalL:Gain 2\" $2 \"finalR:Gain 1\" $1 \"finalR:Gain 2\" $2 ] }" >/dev/null 2>&1 || true
}

apply_preset_params() {
  case "$1" in
    "Gentle"|"Light")
      timeout 2 pw-cli s "$id" Props "{ params = [ \"spectral_karaoke:Depth\" 0.60 \"spectral_karaoke:Low Cutoff (Hz)\" 160.0 \"spectral_karaoke:Air Depth\" 0.35 \"spectral_karaoke:Transient Protection\" 0.70 \"spectral_karaoke:Release (ms)\" 100.0 \"spectral_karaoke:Reverb Duck (dB)\" 1.0 ] }" >/dev/null 2>&1 || true
      ;;
    "Hard")
      timeout 2 pw-cli s "$id" Props "{ params = [ \"spectral_karaoke:Depth\" 0.95 \"spectral_karaoke:Low Cutoff (Hz)\" 130.0 \"spectral_karaoke:Air Depth\" 0.10 \"spectral_karaoke:Transient Protection\" 0.30 \"spectral_karaoke:Release (ms)\" 60.0 \"spectral_karaoke:Reverb Duck (dB)\" 3.5 ] }" >/dev/null 2>&1 || true
      ;;
    "Max"|"Max vocal"|"MaxVocal")
      timeout 2 pw-cli s "$id" Props "{ params = [ \"spectral_karaoke:Depth\" 1.00 \"spectral_karaoke:Low Cutoff (Hz)\" 100.0 \"spectral_karaoke:Air Depth\" 0.05 \"spectral_karaoke:Transient Protection\" 0.20 \"spectral_karaoke:Release (ms)\" 50.0 \"spectral_karaoke:Reverb Duck (dB)\" 5.0 ] }" >/dev/null 2>&1 || true
      ;;
    "Standard"|*)
      timeout 2 pw-cli s "$id" Props "{ params = [ \"spectral_karaoke:Depth\" 0.85 \"spectral_karaoke:Low Cutoff (Hz)\" 150.0 \"spectral_karaoke:Air Depth\" 0.20 \"spectral_karaoke:Transient Protection\" 0.50 \"spectral_karaoke:Release (ms)\" 80.0 \"spectral_karaoke:Reverb Duck (dB)\" 2.5 ] }" >/dev/null 2>&1 || true
      ;;
  esac
}

case "$preset" in
  toggle)
    cur_gain2=$(timeout 2 pw-dump "$id" 2>/dev/null | jq -r '.[].info.params.Props[]?.params[]? // empty' 2>/dev/null | grep -A 1 '^finalL:Gain 2$' | tail -n 1 || echo "0.0")
    if [ "$(awk -v g="$cur_gain2" 'BEGIN { print (g > 0.5) ? 1 : 0 }')" -eq 1 ]; then
      set_mix 1.0 0.0
      notify-send -a "Karaoke" -u low "Karaoke OFF" 2>/dev/null || true
    else
      apply_preset_params "Standard"
      set_mix 0.0 1.0
      notify-send -a "Karaoke" -u low "Karaoke: Standard" 2>/dev/null || true
    fi
    ;;
  trim)
    delta="${2:-0}"
    cur_depth=$(timeout 2 pw-dump "$id" 2>/dev/null | jq -r '.[].info.params.Props[]?.params[]? // empty' 2>/dev/null | grep -A 1 '^spectral_karaoke:Depth$' | tail -n 1 || echo "0.85")
    [ -n "$cur_depth" ] || cur_depth="0.85"
    new_depth=$(awk -v c="$cur_depth" -v d="$delta" 'BEGIN { res = c + d; if (res < 0.0) res = 0.0; if (res > 1.0) res = 1.0; printf "%.2f", res }')
    timeout 2 pw-cli s "$id" Props "{ params = [ \"spectral_karaoke:Depth\" $new_depth ] }" >/dev/null 2>&1 || true
    echo "Karaoke depth trimmed by ${delta}: ${cur_depth} -> ${new_depth}"
    ;;
  off)
    set_mix 1.0 0.0
    notify-send -a "Karaoke" -u low "Karaoke OFF" 2>/dev/null || true
    ;;
  on|"Gentle"|"Light"|"Standard"|"Hard"|"Max"|"Max vocal"|"MaxVocal")
    apply_preset_params "$preset"
    set_mix 0.0 1.0
    notify-send -a "Karaoke" -u low "Karaoke: $preset" 2>/dev/null || true
    ;;
  *)
    exit 0
    ;;
esac
