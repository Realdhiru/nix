#!/usr/bin/env bash
#
# lid-monitor.sh -- one-shot lid event handler invoked by Hyprland bindl.
# NEVER suspends (hard user requirement: logind HandleLidSwitch stays "ignore").

set -uo pipefail

APPLY_PROFILE="$HOME/.config/hypr/scripts/quickshell/battery/apply_profile.sh"
LOCK_SH="$HOME/.config/hypr/scripts/lock.sh"
PROFILE_MARKER="/tmp/qs_power_profile"
SAVED_PROFILE="$HOME/.cache/qs_lid_prev_profile"

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

case "${1:-}" in
    close)
        lock_session
        hyprctl dispatch dpms off
        save_current_profile
        "$APPLY_PROFILE" power-saver
        ;;
    open)
        hyprctl dispatch dpms on
        restore_profile
        ;;
    *)
        echo "Usage: $0 {close|open}"
        exit 1
        ;;
esac