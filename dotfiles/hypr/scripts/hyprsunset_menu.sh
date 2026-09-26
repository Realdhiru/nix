#!/usr/bin/env bash
# ==============================================================================
# hyprsunset_menu.sh -- Fast Hardware CTM Blue Light / Night Light Controller
# Uses kernel DRM/KMS hardware color transform matrix (0% GPU, 0% CPU overhead)
# ==============================================================================
set -euo pipefail

STATE_FILE="$HOME/.cache/hyprsunset_temp"

get_current_temp() {
    if pgrep -x hyprsunset >/dev/null 2>&1; then
        cat "$STATE_FILE" 2>/dev/null || echo "Active"
    else
        echo "Off"
    fi
}

set_temp() {
    local temp="$1"
    pkill -x hyprsunset >/dev/null 2>&1 || true
    if [ "$temp" != "off" ] && [ "$temp" != "0" ]; then
        hyprsunset -t "$temp" >/dev/null 2>&1 &
        echo "$temp" > "$STATE_FILE"
        notify-send -a "Display" -i "display-brightness-symbolic" "Night Light" "Hardware temperature set to ${temp}K"
    else
        rm -f "$STATE_FILE"
        notify-send -a "Display" -i "display-brightness-symbolic" "Night Light" "Hardware display color restored to Normal (6500K)"
    fi
}

# If argument passed directly, set temperature immediately
if [ $# -gt 0 ]; then
    case "$1" in
        toggle)
            if pgrep -x hyprsunset >/dev/null 2>&1; then
                set_temp "off"
            else
                PREV="$(cat "$STATE_FILE" 2>/dev/null || echo "4000")"
                set_temp "$PREV"
            fi
            exit 0
            ;;
        off|0)
            set_temp "off"
            exit 0
            ;;
        *)
            set_temp "$1"
            exit 0
            ;;
    esac
fi

CURR="$(get_current_temp)"

OPTIONS="󰛨  Turn Off (Normal 6500K)\n󱩎  Subtle Warm (5000K)\n󱩏  Cozy Night (4000K)\n󱩐  Deep Amber (3000K)\n󱩑  Candlelight (2200K)\n󰹑  Custom Temperature (K)..."

CHOICE=$(echo -e "$OPTIONS" | fuzzel --dmenu --prompt="Night Light ($CURR) > " --lines=6 --width=35 || true)

[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
    *"Turn Off"*)
        set_temp "off"
        ;;
    *"5000K"*)
        set_temp "5000"
        ;;
    *"4000K"*)
        set_temp "4000"
        ;;
    *"3000K"*)
        set_temp "3000"
        ;;
    *"2200K"*)
        set_temp "2200"
        ;;
    *"Custom"*)
        CUSTOM=$(echo "" | fuzzel --dmenu --prompt="Enter Temperature (1000 - 6500) > " --lines=0 --width=35 || true)
        if [[ "$CUSTOM" =~ ^[0-9]+$ ]] && [ "$CUSTOM" -ge 1000 ] && [ "$CUSTOM" -le 6500 ]; then
            set_temp "$CUSTOM"
        fi
        ;;
esac
