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

wait_for_lock_surface() {
    if locked; then
        return 0
    fi
    
    "$LOCK_SH" >/dev/null 2>&1 &
    
    # Synchronize with Hyprland IPC to fix the display wake bug.
    # Hyprland natively turns on monitors when a new session lock surface maps.
    # We must wait for the lock screen to successfully map BEFORE issuing dpms off.
    # We listen for the 'openlayer>>quickshell' event on the socket2 IPC stream.
    timeout 1.5 socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - | grep -m1 "openlayer>>quickshell" >/dev/null || true
    
    # Extra settlement time for Hyprland's internal compositor state
    sleep 0.2
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
    echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null 2>&1 || \
    echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost >/dev/null 2>&1 || true
}

apply_lid_open_state() {
    # Restore the exact previous Quickshell UI power profile.
    # This automatically writes the correct EPP and Turbo values for that
    # specific profile, completely reversing the temporary lid-closed state.
    restore_profile
}

case "${1:-}" in
    close)
        wait_for_lock_surface
        hyprctl eval "hl.dispatch(hl.dsp.dpms({action='off'}))"
        
        save_current_profile
        apply_lid_closed_state
        ;;
    open)
        hyprctl eval "hl.dispatch(hl.dsp.dpms({action='on'}))"
        apply_lid_open_state
        ;;
    *)
        echo "Usage: $0 {close|open}"
        exit 1
        ;;
esac