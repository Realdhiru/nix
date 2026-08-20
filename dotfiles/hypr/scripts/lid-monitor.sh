#!/usr/bin/env bash
#
# lid-monitor.sh -- one-shot lid event handler invoked by Hyprland bindl.
# NEVER suspends (hard user requirement: logind HandleLidSwitch stays "ignore").

set -uo pipefail

APPLY_PROFILE="$HOME/.config/hypr/scripts/quickshell/battery/apply_profile.sh"
LOCK_SH="$HOME/.config/hypr/scripts/lock.sh"
PROFILE_MARKER="/tmp/qs_power_profile"
SAVED_PROFILE="$HOME/.cache/qs_lid_prev_profile"
SET_EPP="$HOME/.config/hypr/scripts/quickshell/battery/set_epp.sh"

valid_profile() {
    case "$1" in
        performance|balanced|power-saver) return 0 ;;
        *) return 1 ;;
    esac
}

locked() {
    pgrep -f 'quickshell.*Lock\.qml' >/dev/null
}

lock_session() {
    if ! locked; then
        "$LOCK_SH" >/dev/null 2>&1 &
    fi
}

save_current_profile() {
    local cur
    cur=$(cat "$PROFILE_MARKER" 2>/dev/null || echo "")
    if valid_profile "$cur"; then
        echo "$cur" > "$SAVED_PROFILE"
    else
        rm -f "$SAVED_PROFILE"
    fi
}

restore_profile() {
    local saved
    saved=$(cat "$SAVED_PROFILE" 2>/dev/null || echo "")
    if valid_profile "$saved"; then
        if "$APPLY_PROFILE" "$saved"; then
            rm -f "$SAVED_PROFILE"
        fi
    else
        rm -f "$SAVED_PROFILE"
    fi
}

apply_lid_closed_state() {
    # Apply aggressive hardware energy-savings directly without altering the
    # logical Quickshell UI profile (no visual/shader changes). Uses strictly
    # the existing whitelisted sudoers rules.
    
    # 1. EPP=power
    sudo "$SET_EPP" power 2>/dev/null || true
    
    # 2. Disable Turbo Boost
    echo 1 | sudo /run/current-system/sw/bin/tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null 2>&1 || \
    echo 0 | sudo /run/current-system/sw/bin/tee /sys/devices/system/cpu/cpufreq/boost >/dev/null 2>&1 || true
}

apply_lid_open_state() {
    # Restore the exact previous Quickshell UI power profile.
    # This automatically writes the correct EPP and Turbo values for that
    # specific profile, completely reversing the temporary lid-closed state.
    restore_profile
}

case "${1:-}" in
    close)
        # 1. Snapshot the current power state
        save_current_profile
        
        # 2. Lock using Hyprlock (Quickshell Lock.qml)
        lock_session
        
        # 3. Apply ALL temporary low-power changes
        apply_lid_closed_state
        
        # 4. Allow changes, DRM/monitor hotplug events, and Lock surface to settle
        sleep 1
        
        # 5. ONLY NOW issue DPMS OFF (absolute last action)
        hyprctl eval "hl.dispatch(hl.dsp.dpms({action='off'}))"
        ;;
    open)
        # 1. Restore exact previous power state
        apply_lid_open_state
        
        # 2. Allow power changes to settle before restoring display
        sleep 0.2
        
        # 3. Restore display availability
        hyprctl eval "hl.dispatch(hl.dsp.dpms({action='on'}))"
        ;;
    *)
        echo "Usage: $0 {close|open}"
        exit 1
        ;;
esac