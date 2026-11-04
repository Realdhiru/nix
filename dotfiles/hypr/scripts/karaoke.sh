#!/usr/bin/env bash
# karaoke [on|off|toggle|cycle|status]
set -eu

exec 201>"${XDG_RUNTIME_DIR:-/run/user/1000}/karaoke.lock"
flock 201

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/audio"
KARAOKE_STATE="${STATE_DIR}/karaoke.json"
EQ_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/quickshell/music/eq_state.json"
mkdir -p "$STATE_DIR"

get_eq_node_id() {
  local nid
  nid=$(timeout 2 pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_input.eq10"/ {gsub(/,/, "", id); print id; exit}' || true)
  if [ -z "$nid" ]; then
    notify-send -a "Karaoke" -u low "Equalizer Offline" 2>/dev/null || true
    echo "effect_input.eq10 not found" >&2
    exit 0
  fi
  echo "$nid"
}

load_state() {
  if [ -f "$KARAOKE_STATE" ]; then
    cur_enabled=$(jq -r '.enabled // false' "$KARAOKE_STATE" 2>/dev/null || echo "false")
  else
    cur_enabled="false"
  fi
}

save_state() {
  local en="$1"
  local tmp="${KARAOKE_STATE}.tmp.$$"
  jq -n -c --argjson en "$en" '{"enabled": $en}' > "$tmp" 2>/dev/null && mv "$tmp" "$KARAOKE_STATE"
}

set_mix() {
  local nid
  nid=$(get_eq_node_id)
  timeout 2 pw-cli s "$nid" Props "{ params = [ \"finalL:Gain 1\" $1 \"finalL:Gain 2\" $2 \"finalR:Gain 1\" $1 \"finalR:Gain 2\" $2 ] }" >/dev/null 2>&1 || true
}

apply_preset_params() {
  local nid
  nid=$(get_eq_node_id)
  timeout 2 pw-cli s "$nid" Props "{ params = [ \
    \"spectral_karaoke:Depth\" 1.0 \
    \"spectral_karaoke:Low Cutoff (Hz)\" 50.0 \
    \"spectral_karaoke:Air Depth\" 0.95 \
    \"spectral_karaoke:Transient Protection\" 0.0 \
    \"spectral_karaoke:Release (ms)\" 120.0 \
    \"spectral_karaoke:Reverb Duck (dB)\" 0.0 \
  ] }" >/dev/null 2>&1 || true
}

update_eq_preset() {
  local p="$1"
  if [ -f "$EQ_STATE" ]; then
    local tmp="${EQ_STATE}.tmp.$$"
    if [ "$p" = "Karaoke" ]; then
      jq -c '.b1=0 | .b2=0 | .b3=0 | .b4=-2 | .b5=-4 | .b6=-6 | .b7=-4 | .b8=-2 | .b9=0 | .b10=1 | .preset="Karaoke" | .pending=false' "$EQ_STATE" > "$tmp" 2>/dev/null && mv "$tmp" "$EQ_STATE"
      local nid
      nid=$(get_eq_node_id 2>/dev/null || true)
      if [ -n "$nid" ]; then
        pw-cli s "$nid" Props "{ params = [ \
          \"eq_band_1_l:Gain\" 0 \"eq_band_1_r:Gain\" 0 \
          \"eq_band_2_l:Gain\" 0 \"eq_band_2_r:Gain\" 0 \
          \"eq_band_3_l:Gain\" 0 \"eq_band_3_r:Gain\" 0 \
          \"eq_band_4_l:Gain\" -2 \"eq_band_4_r:Gain\" -2 \
          \"eq_band_5_l:Gain\" -4 \"eq_band_5_r:Gain\" -4 \
          \"eq_band_6_l:Gain\" -6 \"eq_band_6_r:Gain\" -6 \
          \"eq_band_7_l:Gain\" -4 \"eq_band_7_r:Gain\" -4 \
          \"eq_band_8_l:Gain\" -2 \"eq_band_8_r:Gain\" -2 \
          \"eq_band_9_l:Gain\" 0 \"eq_band_9_r:Gain\" 0 \
          \"eq_band_10_l:Gain\" 1 \"eq_band_10_r:Gain\" 1 \
        ] }" >/dev/null 2>&1 || true
      fi
    elif [ "$p" = "Off" ]; then
      local cur_p
      cur_p=$(jq -r '.preset // "Off"' "$EQ_STATE" 2>/dev/null || echo "Off")
      if [ "$cur_p" = "Karaoke" ]; then
        jq -c '.b1=0 | .b2=0 | .b3=0 | .b4=0 | .b5=0 | .b6=0 | .b7=0 | .b8=0 | .b9=0 | .b10=0 | .preset="Off" | .pending=false' "$EQ_STATE" > "$tmp" 2>/dev/null && mv "$tmp" "$EQ_STATE"
        local nid
        nid=$(get_eq_node_id 2>/dev/null || true)
        if [ -n "$nid" ]; then
          pw-cli s "$nid" Props "{ params = [ \
            \"eq_band_1_l:Gain\" 0 \"eq_band_1_r:Gain\" 0 \
            \"eq_band_2_l:Gain\" 0 \"eq_band_2_r:Gain\" 0 \
            \"eq_band_3_l:Gain\" 0 \"eq_band_3_r:Gain\" 0 \
            \"eq_band_4_l:Gain\" 0 \"eq_band_4_r:Gain\" 0 \
            \"eq_band_5_l:Gain\" 0 \"eq_band_5_r:Gain\" 0 \
            \"eq_band_6_l:Gain\" 0 \"eq_band_6_r:Gain\" 0 \
            \"eq_band_7_l:Gain\" 0 \"eq_band_7_r:Gain\" 0 \
            \"eq_band_8_l:Gain\" 0 \"eq_band_8_r:Gain\" 0 \
            \"eq_band_9_l:Gain\" 0 \"eq_band_9_r:Gain\" 0 \
            \"eq_band_10_l:Gain\" 0 \"eq_band_10_r:Gain\" 0 \
          ] }" >/dev/null 2>&1 || true
        fi
      fi
    fi
  fi
}

cmd="${1:-toggle}"

load_state

case "$cmd" in
  on)
    if [ "$cur_enabled" = "true" ]; then
      apply_preset_params
      echo "Karaoke is already active"
      exit 0
    fi
    set_mix 0.0 1.0
    apply_preset_params
    save_state true
    update_eq_preset "Karaoke"
    notify-send -a "Karaoke" -u low "Karaoke ON" 2>/dev/null || true
    echo "Karaoke ON"
    ;;

  off)
    if [ "$cur_enabled" = "true" ]; then
      set_mix 1.0 0.0
      save_state false
      update_eq_preset "Off"
      notify-send -a "Karaoke" -u low "Karaoke OFF" 2>/dev/null || true
      echo "Karaoke OFF"
    else
      exit 0
    fi
    ;;

  toggle|cycle)
    if [ "$cur_enabled" = "true" ]; then
      set_mix 1.0 0.0
      save_state false
      update_eq_preset "Off"
      notify-send -a "Karaoke" -u low "Karaoke OFF" 2>/dev/null || true
      echo "Karaoke OFF"
    else
      set_mix 0.0 1.0
      apply_preset_params
      save_state true
      update_eq_preset "Karaoke"
      notify-send -a "Karaoke" -u low "Karaoke ON" 2>/dev/null || true
      echo "Karaoke ON"
    fi
    ;;

  status)
    echo "enabled=$cur_enabled"
    ;;

  *)
    exit 0
    ;;
esac
