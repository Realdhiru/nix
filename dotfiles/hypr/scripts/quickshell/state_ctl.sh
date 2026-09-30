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
        if command -v jq >/dev/null 2>&1; then
            jq -r ".$KEY | if . != null then . else empty end" "$STATE_FILE"
        else
            python3 -c "import json, sys, os; d=json.load(open(os.path.expanduser('$STATE_FILE'))); keys='$KEY'.split('.'); v=d; [v:=v.get(k, {}) for k in keys if isinstance(v, dict)]; print(v if not isinstance(v, dict) else '')"
        fi
        ;;

    set)
        # Usage: state_ctl.sh set modes.dnd true
        KEY="$2"
        VAL="$3"
        python3 -c "
import json, os, sys
p = os.path.expanduser('$STATE_FILE')
try:
    with open(p, 'r') as f: d = json.load(f)
except Exception: d = {}

keys = '$KEY'.split('.')
val_str = '$VAL'
if val_str == 'true': val = True
elif val_str == 'false': val = False
elif val_str.isdigit(): val = int(val_str)
else:
    try: val = float(val_str)
    except ValueError: val = val_str

curr = d
for k in keys[:-1]:
    if k not in curr or not isinstance(curr[k], dict):
        curr[k] = {}
    curr = curr[k]
curr[keys[-1]] = val

with open(p, 'w') as f:
    json.dump(d, f, indent=2)
"
        ;;

    sunset)
        # Usage: state_ctl.sh sunset 6500 100 100 0 0 false
        TEMP="${2:-6500}"
        GAMMA="${3:-100}"
        SAT="${4:-100}"
        GRAIN="${5:-0}"
        CRT="${6:-0}"
        ACTIVE="${7:-false}"

        python3 -c "
import json, os
p = os.path.expanduser('$STATE_FILE')
try:
    with open(p, 'r') as f: d = json.load(f)
except Exception: d = {}

d['sunset'] = {
    'temp': int('$TEMP'),
    'gamma': int('$GAMMA'),
    'sat': int('$SAT'),
    'grain': int('$GRAIN'),
    'crt': int('$CRT'),
    'active': '$ACTIVE' == 'true'
}

with open(p, 'w') as f:
    json.dump(d, f, indent=2)
"
        ;;

    *)
        echo "Usage: $0 {get|set|sunset} [args...]"
        exit 1
        ;;
esac
