#!/usr/bin/env bash
# karaoke [on|off|toggle|cycle|status|Gentle|Standard|Hard|Max|trim]
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
    cur_mode=$(jq -r '.mode // "Standard"' "$KARAOKE_STATE" 2>/dev/null || echo "Standard")
  else
    cur_enabled="false"
    cur_mode="Standard"
  fi
  case "$cur_mode" in
    "Gentle"|"Standard"|"Hard"|"Max") ;;
    *) cur_mode="Standard" ;;
  esac
}

save_state() {
  local en="$1"
  local md="$2"
  local tmp="${KARAOKE_STATE}.tmp.$$"
  jq -n -c --argjson en "$en" --arg md "$md" '{"enabled": $en, "mode": $md}' > "$tmp" 2>/dev/null && mv "$tmp" "$KARAOKE_STATE"
}

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

update_eq_preset() {
  local p="$1"
  if [ -f "$EQ_STATE" ]; then
    local tmp="${EQ_STATE}.tmp.$$"
    jq -c --arg p "$p" '.preset = $p' "$EQ_STATE" > "$tmp" 2>/dev/null && mv "$tmp" "$EQ_STATE"
  fi
}

cmd="${1:-cycle}"

load_state

case "$cmd" in
  cycle)
    if [ "$cur_enabled" != "true" ]; then
      next_mode="Standard"
      set_mix 0.0 1.0
      apply_preset_params "$next_mode"
      save_state true "$next_mode"
      update_eq_preset "Karaoke"
      notify-send -a "Karaoke" -u low "Karaoke: $next_mode" 2>/dev/null || true
      echo "Karaoke: $next_mode"
    else
      case "$cur_mode" in
        "Standard") next_mode="Hard" ;;
        "Hard")     next_mode="Max" ;;
        "Max")      next_mode="Gentle" ;;
        "Gentle")   next_mode="Off" ;;
        *)          next_mode="Standard" ;;
      esac

      if [ "$next_mode" = "Off" ]; then
        set_mix 1.0 0.0
        save_state false "$cur_mode"
        update_eq_preset "Off"
        notify-send -a "Karaoke" -u low "Karaoke OFF" 2>/dev/null || true
        echo "Karaoke OFF"
      else
        set_mix 0.0 1.0
        apply_preset_params "$next_mode"
        save_state true "$next_mode"
        update_eq_preset "Karaoke"
        notify-send -a "Karaoke" -u low "Karaoke: $next_mode" 2>/dev/null || true
        echo "Karaoke: $next_mode"
      fi
    fi
    ;;

  toggle)
    if [ "$cur_enabled" = "true" ]; then
      set_mix 1.0 0.0
      save_state false "$cur_mode"
      update_eq_preset "Off"
      notify-send -a "Karaoke" -u low "Karaoke OFF" 2>/dev/null || true
      echo "Karaoke OFF"
    else
      target_mode="${cur_mode:-Standard}"
      set_mix 0.0 1.0
      apply_preset_params "$target_mode"
      save_state true "$target_mode"
      update_eq_preset "Karaoke"
      notify-send -a "Karaoke" -u low "Karaoke: $target_mode" 2>/dev/null || true
      echo "Karaoke: $target_mode"
    fi
    ;;

  on)
    if [ "$cur_enabled" = "true" ]; then
      echo "Karaoke is already active: $cur_mode"
    else
      target_mode="${cur_mode:-Standard}"
      set_mix 0.0 1.0
      apply_preset_params "$target_mode"
      save_state true "$target_mode"
      update_eq_preset "Karaoke"
      notify-send -a "Karaoke" -u low "Karaoke: $target_mode" 2>/dev/null || true
      echo "Karaoke: $target_mode"
    fi
    ;;

  off)
    set_mix 1.0 0.0
    save_state false "$cur_mode"
    update_eq_preset "Off"
    notify-send -a "Karaoke" -u low "Karaoke OFF" 2>/dev/null || true
    echo "Karaoke OFF"
    ;;

  status)
    echo "enabled=$cur_enabled mode=$cur_mode"
    ;;

  trim)
    delta="${2:-0}"
    cur_depth=$(timeout 2 pw-dump "$id" 2>/dev/null | jq -r '.[].info.params.Props[]?.params[]? // empty' 2>/dev/null | grep -A 1 '^spectral_karaoke:Depth$' | tail -n 1 || echo "0.85")
    [ -n "$cur_depth" ] || cur_depth="0.85"
    new_depth=$(awk -v c="$cur_depth" -v d="$delta" 'BEGIN { res = c + d; if (res < 0.0) res = 0.0; if (res > 1.0) res = 1.0; printf "%.2f", res }')
    timeout 2 pw-cli s "$id" Props "{ params = [ \"spectral_karaoke:Depth\" $new_depth ] }" >/dev/null 2>&1 || true
    echo "Karaoke depth trimmed by ${delta}: ${cur_depth} -> ${new_depth}"
    ;;

  Gentle|Light|Standard|Hard|Max|"Max vocal"|MaxVocal)
    normalized="$cmd"
    case "$cmd" in
      Light) normalized="Gentle" ;;
      "Max vocal"|MaxVocal) normalized="Max" ;;
    esac
    apply_preset_params "$normalized"
    set_mix 0.0 1.0
    save_state true "$normalized"
    update_eq_preset "Karaoke"
    notify-send -a "Karaoke" -u low "Karaoke: $normalized" 2>/dev/null || true
    echo "Karaoke: $normalized"
    ;;

  *)
    exit 0
    ;;
esac
