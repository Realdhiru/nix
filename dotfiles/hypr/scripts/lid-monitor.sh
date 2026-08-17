#!/usr/bin/env bash
#
# lid-monitor.sh -- event-driven lid watcher. NEVER suspends (hard user
# requirement: logind HandleLidSwitch stays "ignore"; suspend is manual
# via Shift+Esc only).
#
# Lid close -> snapshot the active profile, display off, then power-saver
#              (CPU EPP/turbo/RR/shader-cut via apply_profile.sh). The DPMS
#              action is a DIRECT compositor-socket call: it is intentionally
#              NOT idle-aware, so Coffee Mode (systemd-inhibit --what=idle,
#              which only gates hypridle's idle detection) can never prevent
#              or delay it.
# Lid open  -> display on, then restore the EXACT profile that was active
#              before close (snapshot in ~/.cache/qs_lid_prev_profile; the
#              marker's existence arms the restore, mirroring apply_profile's
#              qs_pre_saver_shader.conf pattern). AC -> performance / battery
#              -> balanced fallback only when no valid snapshot exists.
#              Profile application is delegated wholesale to apply_profile.sh
#              (single source of truth) - no power logic is duplicated here.
#
# Event source is udevadm (kernel button subsystem), not polling. A
# reconnect loop keeps the watcher alive across udev restarts.

set -uo pipefail

LID=$(echo /proc/acpi/button/lid/LID*)
APPLY_PROFILE="$HOME/.config/hypr/scripts/quickshell/battery/apply_profile.sh"
PROFILE_STATE="/tmp/qs_power_profile"
PREV_PROFILE="$HOME/.cache/qs_lid_prev_profile"

read_lid_state() {
    awk '{print $2}' "$LID/state" 2>/dev/null
}

ac_online() {
    local f v
    for f in /sys/class/power_supply/*/online; do
        [ -r "$f" ] || continue
        read -r v < "$f"
        printf '%s' "$v"
        return
    done
    printf '0'
}

save_prev_profile() {
    local cur
    cur=$(cat "$PROFILE_STATE" 2>/dev/null)
    case "$cur" in
        performance|balanced|power-saver)
            # only the FIRST snapshot in a close-cycle survives
            [[ -f "$PREV_PROFILE" ]] || echo "$cur" > "$PREV_PROFILE"
            ;;
    esac
}

restore_prev_profile() {
    local prev
    prev=$(cat "$PREV_PROFILE" 2>/dev/null)
    case "$prev" in
        performance|balanced|power-saver)
            "$APPLY_PROFILE" "$prev"
            ;;
        *)
            # no valid snapshot (first boot with lid closed, /tmp cleared,
            # corruption) -> keep the established AC/BAT default
            if [[ "$(ac_online)" == "1" ]]; then
                "$APPLY_PROFILE" performance
            else
                "$APPLY_PROFILE" balanced
            fi
            ;;
    esac
    rm -f "$PREV_PROFILE"
}

apply_state() {
    local state="$1"
    if [[ "$state" == "closed" ]]; then
        save_prev_profile
        hyprctl eval "hl.dispatch(hl.dsp.dpms({action='off'}))"
        "$APPLY_PROFILE" power-saver
    else
        hyprctl eval "hl.dispatch(hl.dsp.dpms({action='on'}))"
        restore_prev_profile
    fi
}

# Event loop: kernel button subsystem fires "change" uevents on lid toggles.
# run_monitor is re-invoked if udevadm ever dies; it re-syncs from the
# current lid state first, so a missed toggle during the gap is caught.
run_monitor() {
    local last state line
    last=$(read_lid_state)
    apply_state "$last"

    udevadm monitor --kernel --subsystem-match=button 2>/dev/null | while read -r line; do
        case "$line" in
            *button*|*lid*)
                state=$(read_lid_state)
                if [[ "$state" != "$last" ]]; then
                    apply_state "$state"
                    last="$state"
                fi
                ;;
        esac
    done
}

while true; do
    run_monitor
    sleep 1
done
