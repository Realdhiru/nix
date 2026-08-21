#!/usr/bin/env bash
#
# suspend.sh -- centralized sleep and resume handler.
# Integrates with the lid-monitor state machine.

set -uo pipefail

LOCK_SH="$HOME/.config/hypr/scripts/lock.sh"
LID_MONITOR="$HOME/.config/hypr/scripts/lid-monitor.sh"

case "${1:-}" in
    suspend)
        # 1. Lock the session asynchronously if not already locked
        if ! pgrep -f 'quickshell.*Lock\.qml' >/dev/null; then
            "$LOCK_SH" >/dev/null 2>&1 &
        fi
        
        # 2. Allow lock surface to map safely before suspend (prevents GPU lock-crashes)
        sleep 1
        
        # 3. Issue deep suspend
        systemctl suspend
        ;;
        
    resume)
        # 1. Wait momentarily for DRM, ACPI, and libinput state to settle after hardware wake
        sleep 1
        
        # 2. Determine post-resume routing
        if grep -iq "closed" /proc/acpi/button/lid/*/state 2>/dev/null; then
            # The machine woke up, but the lid is STILL closed (e.g. bag-wake from RTC or USB).
            # Enforce the lid-closed state (CPU throttle + DPMS off) immediately.
            "$LID_MONITOR" close
        else
            # Lid is open, restore normal display availability
            hyprctl eval "hl.dispatch(hl.dsp.dpms({action='on'}))"
        fi
        ;;
        
    *)
        echo "Usage: $0 {suspend|resume}"
        exit 1
        ;;
esac
