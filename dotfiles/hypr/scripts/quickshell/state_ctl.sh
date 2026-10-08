#!/usr/bin/env bash
# QuickShell State Controller Utility
# Manages reading and updating ~/.cache/quickshell/state.json cleanly

STATE_DIR="$HOME/.cache/quickshell"
STATE_FILE="$STATE_DIR/state.json"

mkdir -p "$STATE_DIR"

if [ ! -f "$STATE_FILE" ]; then
    cat <<'EOF' > "$STATE_FILE"
{
  "version": 1,
  "sunset": {
    "temp": 6500,
    "gamma": 100,
    "sat": 100,
    "grain": 0,
    "crt": 0,
    "active": false
  },
  "modes": {
    "gaming": false,
    "wallpaperKilled": false,
    "dnd": false,
    "coffee": false
  },
  "power": {
    "profile": "balanced"
  },
  "ui": {
    "wallpaperFilter": "All",
    "networkMode": "wifi"
  }
}
EOF
fi

ACTION="$1"

case "$ACTION" in
    get)
        # Usage: state_ctl.sh get sunset.temp
        KEY="$2"
        jq -r ".$KEY | if . != null then . else empty end" "$STATE_FILE" 2>/dev/null || true
        ;;

    set)
        # Usage: state_ctl.sh set modes.dnd true
        KEY="$2"
        VAL="$3"
        # Parse path array
        IFS='.' read -r -a PATH_PARTS <<< "$KEY"
        PATH_JSON=$(printf '%s\n' "${PATH_PARTS[@]}" | jq -R . | jq -s .)
        
        # Determine value type (boolean, number, or string)
        if [ "$VAL" = "true" ] || [ "$VAL" = "false" ]; then
            VAL_ARG="--argjson v $VAL"
        elif [[ "$VAL" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
            VAL_ARG="--argjson v $VAL"
        else
            VAL_ARG="--arg v $VAL"
        fi

        jq --argjson p "$PATH_JSON" $VAL_ARG 'setpath($p; $v)' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
        ;;

    sunset)
        # Usage: state_ctl.sh sunset 6500 100 100 0 0 false
        TEMP="${2:-6500}"
        GAMMA="${3:-100}"
        SAT="${4:-100}"
        GRAIN="${5:-0}"
        CRT="${6:-0}"
        ACTIVE="${7:-false}"
        [ "$ACTIVE" != "true" ] && ACTIVE="false"

        jq --argjson temp "$TEMP" \
           --argjson gamma "$GAMMA" \
           --argjson sat "$SAT" \
           --argjson grain "$GRAIN" \
           --argjson crt "$CRT" \
           --argjson active "$ACTIVE" \
           '.sunset = {temp: $temp, gamma: $gamma, sat: $sat, grain: $grain, crt: $crt, active: $active}' \
           "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE"
        ;;

    *)
        echo "Usage: $0 {get|set|sunset} [args...]"
        exit 1
        ;;
esac
