#!/usr/bin/env bash
# karaoke [on|off|toggle|cycle|status]
set -eu

exec 201>"${XDG_RUNTIME_DIR:-/run/user/1000}/karaoke.lock"
flock 201

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/audio"
KARAOKE_STATE="${STATE_DIR}/karaoke.json"
EQ_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/quickshell/music/eq_state.json"
mkdir -p "$STATE_DIR"

id=$(timeout 2 pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_input.eq10"/ {gsub(/,/, "", id); print id; exit}' || true)
if [ -z "$id" ]; then
    notify-send -a "Karaoke" -u low "Equalizer Offline" 2>/dev/null || true
    echo "effect_input.eq10 not found" >&2
    exit 0
fi

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
  timeout 2 pw-cli s "$id" Props "{ params = [ \"finalL:Gain 1\" $1 \"finalL:Gain 2\" $2 \"finalR:Gain 1\" $1 \"finalR:Gain 2\" $2 ] }" >/dev/null 2>&1 || true
}

apply_preset_params() {
  timeout 2 pw-cli s "$id" Props "{ params = [ \
    \"spectral_karaoke:Depth\" 0.95 \
    \"spectral_karaoke:Low Cutoff (Hz)\" 140.0 \
    \"spectral_karaoke:Air Depth\" 0.15 \
    \"spectral_karaoke:Transient Protection\" 0.60 \
    \"spectral_karaoke:Release (ms)\" 70.0 \
    \"spectral_karaoke:Reverb Duck (dB)\" 3.0 \
  ] }" >/dev/null 2>&1 || true
}

update_eq_preset() {
  local p="$1"
  if [ -f "$EQ_STATE" ]; then
    local cur_p
    cur_p=$(jq -r '.preset // "Off"' "$EQ_STATE" 2>/dev/null || echo "Off")
    if [ "$p" = "Off" ]; then
      if [ "$cur_p" = "Karaoke" ]; then
        local tmp="${EQ_STATE}.tmp.$$"
        jq -c '.preset = "Off"' "$EQ_STATE" > "$tmp" 2>/dev/null && mv "$tmp" "$EQ_STATE"
      fi
    else
      local tmp="${EQ_STATE}.tmp.$$"
      jq -c --arg p "$p" '.preset = $p' "$EQ_STATE" > "$tmp" 2>/dev/null && mv "$tmp" "$EQ_STATE"
    fi
  fi
}

cmd="${1:-toggle}"

load_state

case "$cmd" in
  on)
    set_mix 0.0 1.0
    apply_preset_params
    save_state true
    update_eq_preset "Karaoke"
    if [ "$cur_enabled" != "true" ]; then
      notify-send -a "Karaoke" -u low "Karaoke ON" 2>/dev/null || true
      echo "Karaoke ON"
    else
      echo "Karaoke is already active"
    fi
    ;;

  off)
    set_mix 1.0 0.0
    if [ "$cur_enabled" = "true" ]; then
      save_state false
      update_eq_preset "Off"
      notify-send -a "Karaoke" -u low "Karaoke OFF" 2>/dev/null || true
      echo "Karaoke OFF"
    else
      save_state false
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
