#!/usr/bin/env bash
# QuickShell Sunset / Night Light Instant Toggle Utility
STATE_DIR="$HOME/.cache/quickshell"
STATE_FILE="$STATE_DIR/state.json"
SAVED_FILE="$STATE_DIR/sunset_saved.json"
SHADER_FILE="$HOME/.cache/screen_shader.frag"

mkdir -p "$STATE_DIR"

IS_RUNNING=0
if pgrep -x hyprsunset >/dev/null 2>&1 || [ -f "$SHADER_FILE" ]; then
    IS_RUNNING=1
fi

if [ "$IS_RUNNING" -eq 1 ]; then
    # Currently ON -> Save state and turn OFF
    if [ -f "$STATE_FILE" ]; then
        jq '.sunset // {} | if (.temp != 6500 or .gamma != 100 or .sat != 100) then . else empty end' "$STATE_FILE" > "$SAVED_FILE.tmp" 2>/dev/null && \
        mv "$SAVED_FILE.tmp" "$SAVED_FILE" 2>/dev/null || true
    fi

    # Disable hyprsunset
    if pgrep -x hyprsunset >/dev/null 2>&1; then
        hyprctl hyprsunset identity >/dev/null 2>&1 || true
        hyprctl hyprsunset gamma 100 >/dev/null 2>&1 || true
        pkill -x hyprsunset >/dev/null 2>&1 || true
    fi

    # Disable shaders
    hyprctl eval "hl.config({ decoration = { screen_shader = '' } })" >/dev/null 2>&1 || true
    rm -f "$SHADER_FILE" "$HOME/.cache/screen_saturation.frag"

    # Update state.json: temp=6500, gamma=100, sat=100, grain=0, crt=0, active=false
    bash "$HOME/.config/hypr/scripts/quickshell/state_ctl.sh" sunset 6500 100 100 0 0 false

    notify-send -u low "Night Light OFF"
else
    # Currently OFF -> Restore state and turn ON
    RESTORED=0
    if [ -s "$SAVED_FILE" ] && [ -f "$STATE_FILE" ]; then
        if jq --slurpfile s "$SAVED_FILE" '.sunset = ($s[0] + {active: true})' "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null; then
            mv "$STATE_FILE.tmp" "$STATE_FILE"
            RESTORED=1
        fi
    fi

    if [ "$RESTORED" -eq 0 ]; then
        # Default warm sunset (4500K)
        bash "$HOME/.config/hypr/scripts/quickshell/state_ctl.sh" sunset 4500 100 100 0 0 true
    fi

    bash "$HOME/.config/hypr/scripts/quickshell/restore_state.sh"
    notify-send -u low "Night Light ON"
fi
