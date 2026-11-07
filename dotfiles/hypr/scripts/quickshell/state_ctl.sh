#!/usr/bin/env bash
# QuickShell State Controller Utility
# Manages reading and updating ${DESKTOP_STATE_DIR:-$HOME/.local/state/desktop}/quickshell/state.json cleanly
# Enforces flock synchronization and atomic temp+rename writes to prevent corruption.

set -euo pipefail

DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
STATE_DIR="$DESKTOP_STATE_DIR/quickshell"
STATE_FILE="$STATE_DIR/state.json"
LOCK_FILE="$STATE_DIR/.state.lock"

mkdir -p "$STATE_DIR"

exec 201>"$LOCK_FILE"
flock -w 5 201 || { echo "state_ctl.sh: state lock timed out" >&2; exit 1; }

# Initialize or repair state.json if absent or corrupted
if [ ! -s "$STATE_FILE" ] || ! jq empty "$STATE_FILE" 2>/dev/null; then
    cat <<'EOF' > "$STATE_FILE.tmp.$$"
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
    mv -f "$STATE_FILE.tmp.$$" "$STATE_FILE"
fi

ACTION="${1:-}"

case "$ACTION" in
    get)
        KEY="${2:-}"
        [ -z "$KEY" ] && exit 0
        jq -r ".$KEY | if . != null then . else empty end" "$STATE_FILE" 2>/dev/null || true
        ;;

    set)
        KEY="${2:-}"
        VAL="${3:-}"
        [ -z "$KEY" ] && exit 0

        IFS='.' read -r -a PATH_PARTS <<< "$KEY"
        PATH_JSON=$(printf '%s\n' "${PATH_PARTS[@]}" | jq -R . | jq -s .)
        
        val_args=()
        if [ "$VAL" = "true" ] || [ "$VAL" = "false" ]; then
            val_args=(--argjson v "$VAL")
        elif [[ "$VAL" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
            val_args=(--argjson v "$VAL")
        else
            val_args=(--arg v "$VAL")
        fi

        TMP="$STATE_FILE.tmp.$$$RANDOM"
        if jq --argjson p "$PATH_JSON" "${val_args[@]}" 'setpath($p; $v)' "$STATE_FILE" > "$TMP" 2>/dev/null && jq empty "$TMP" 2>/dev/null; then
            mv -f "$TMP" "$STATE_FILE"
        else
            rm -f "$TMP"
        fi
        ;;

    sunset)
        TEMP="${2:-6500}"
        GAMMA="${3:-100}"
        SAT="${4:-100}"
        GRAIN="${5:-0}"
        CRT="${6:-0}"
        ACTIVE="${7:-false}"
        [ "$ACTIVE" != "true" ] && ACTIVE="false"

        TMP="$STATE_FILE.tmp.$$$RANDOM"
        if jq --argjson temp "$TEMP" \
           --argjson gamma "$GAMMA" \
           --argjson sat "$SAT" \
           --argjson grain "$GRAIN" \
           --argjson crt "$CRT" \
           --argjson active "$ACTIVE" \
           '.sunset = {temp: $temp, gamma: $gamma, sat: $sat, grain: $grain, crt: $crt, active: $active}' \
           "$STATE_FILE" > "$TMP" 2>/dev/null && jq empty "$TMP" 2>/dev/null; then
            mv -f "$TMP" "$STATE_FILE"
        else
            rm -f "$TMP"
        fi
        ;;

    modes)
        GAMING="${2:-false}"
        WP_KILLED="${3:-false}"
        COFFEE="${4:-false}"
        TMP="$STATE_FILE.tmp.$$$RANDOM"
        if jq --argjson g "$GAMING" --argjson w "$WP_KILLED" --argjson c "$COFFEE" \
           '.modes = {gaming: $g, wallpaperKilled: $w, coffee: $c}' \
           "$STATE_FILE" > "$TMP" 2>/dev/null && jq empty "$TMP" 2>/dev/null; then
            mv -f "$TMP" "$STATE_FILE"
        else
            rm -f "$TMP"
        fi
        ;;

    *)
        echo "Usage: $0 {get|set|sunset|modes} [args...]"
        exit 1
        ;;
esac

flock -u 201
