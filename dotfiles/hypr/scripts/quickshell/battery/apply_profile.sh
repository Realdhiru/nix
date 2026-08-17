#!/usr/bin/env bash
#
# apply_profile.sh -- single source of truth for the desktop-visible power
# profile: EPP, CPU turbo/boost, internal-monitor refresh rate, and the
# shader/blur/shadow cut for power-saver.
#
# Consumers:
#   - SysData.qml setPowerProfile() (BatteryPopup profile picker)
#   - lid-monitor.sh (lid close -> power-saver, lid open -> restore)
#
# Scope notes (do not expand):
#   - intentionally no `tlp ac`/`tlp bat` here; AC/BAT mode switching is owned
#     exclusively by the udev rule in power.nix.
#   - the pre-saver shader state is kept in ~/.cache/qs_pre_saver_shader.conf;
#     its existence doubles as the "was in power-saver" flag, so entering
#     saver twice never re-captures, and leaving saver always restores.

set -uo pipefail

name="${1:-}"
prevProfile="${2:-}"

case "$name" in
    performance|balanced|power-saver) ;;
    *) echo "apply_profile.sh: unknown profile: '$name'" >&2; exit 1 ;;
esac

echo "$name" > /tmp/qs_power_profile

eppMode="balance_performance"
targetRR=120
case "$name" in
    performance) eppMode="performance" ;;
    power-saver) eppMode="power"; targetRR=60 ;;
esac

disableTurbo=0
if [ "$name" = "power-saver" ]; then disableTurbo=1; fi

sudo "$HOME/.config/hypr/scripts/quickshell/battery/set_epp.sh" "$eppMode" 2>/dev/null
if [ "$disableTurbo" = "1" ]; then
    echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost 2>/dev/null
else
    echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo 1 | sudo tee /sys/devices/system/cpu/cpufreq/boost 2>/dev/null
fi

INT_MON=$(hyprctl monitors -j | jq -r '.[] | select(.name | test("eDP|LVDS|MIPI")).name' | head -n1)

if [ -n "$INT_MON" ]; then
    RES=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n) | "\(.width)x\(.height)"')
    SCALE=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n).scale')
    TRANSFORM=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n).transform')
    TRANSFORM_STR=""
    [ -n "$TRANSFORM" ] && [ "$TRANSFORM" != "0" ] && TRANSFORM_STR=",transform,$TRANSFORM"

    echo "monitor=$INT_MON,$RES@${targetRR},auto,$SCALE,bitdepth,10$TRANSFORM_STR" > "$HOME/.cache/hypr_power_monitor.conf"

    CUR_RR=$(hyprctl monitors -j | jq -r --arg n "$INT_MON" '.[] | select(.name==$n).refreshRate' | awk '{print int($1 + 0.5)}')
    if [ "$CUR_RR" != "${targetRR}" ]; then
        hyprctl eval "hl.monitor({output='$INT_MON',mode='$RES@${targetRR}',position='auto',scale='$SCALE',bitdepth=10,transform=${TRANSFORM:-0}})" 2>/dev/null
    fi
fi

PRE_SAVER="$HOME/.cache/qs_pre_saver_shader.conf"

if [ "$name" = "power-saver" ] && [ ! -f "$PRE_SAVER" ]; then
    hyprctl -j getoption decoration:screen_shader | jq -r '.str' > "$PRE_SAVER" 2>/dev/null
    hyprctl eval "hl.config({decoration={screen_shader=''}})" 2>/dev/null
    hyprctl eval "hl.config({decoration={blur={enabled=0}}})" 2>/dev/null
    hyprctl eval "hl.config({decoration={shadow={enabled=0}}})" 2>/dev/null
elif [ "$name" != "power-saver" ] && [ -f "$PRE_SAVER" ]; then
    PREV_SHADER=$(cat "$PRE_SAVER" 2>/dev/null || echo "")
    hyprctl eval "hl.config({decoration={screen_shader='$PREV_SHADER'}})" 2>/dev/null
    hyprctl eval "hl.config({decoration={blur={enabled=1}}})" 2>/dev/null
    hyprctl eval "hl.config({decoration={shadow={enabled=1}}})" 2>/dev/null
    rm -f "$PRE_SAVER"
fi
