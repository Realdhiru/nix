#!/usr/bin/env bash
#
# lid-monitor.sh -- event-driven lid watcher. NEVER suspends (hard user
# requirement: logind HandleLidSwitch stays "ignore"; suspend is manual
# via Shift+Esc only).
#
# Lid close -> lock session (existing Quickshell Lock.qml lock, same
# mechanism hypridle uses), then display off, then save the exact active
# power profile, then power-saver via apply_profile.sh. The DPMS action
# is a DIRECT compositor-socket call: it is intentionally NOT idle-aware,
# so Coffee Mode (systemd-inhibit --what=idle, which only gates
# hypridle's idle detection) can never prevent or delay it.
# Lid open  -> display on, then restore the exact profile saved at lid
# close (apply_profile.sh <saved>; the saved-profile marker is removed
# only after a successful restore). No AC/BAT fallback when a valid
# saved profile exists; if none exists (or it is invalid), the profile
# is left untouched.
#
# Event source: a blocking read on the lid-switch input device (SW_LID
# / EV_SW). The node is discovered dynamically from
# /proc/bus/input/devices and accessed via an ACL granted by a narrowly
# scoped uaccess udev rule (ID_PATH of the PNP0C0D device only -- NOT
# the input group). Input events are kernel-pushed: no polling, no
# timers, no sleeps on the success path. The event only TRIGGERS
# sync_state(); the authoritative lid state is always re-read from
# /proc/acpi/button/lid/LID/state (transition-only, idempotent).
#
# udevadm-monitor is NOT used: verified empirically that this lid device
# emits no kernel uevent (two independent monitors saw zero lid events
# across several real toggles), which made the old watcher degrade to a
# silent 2.2s poll. A 0.2s backoff exists ONLY on open/read failure of
# the device node (error-loop guard); it never runs after a successful
# event. sync_state() at startup reconciles the state file.

set -uo pipefail

LID=$(echo /proc/acpi/button/lid/LID*)
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

read_lid_state() {
    awk '{print $2}' "$LID/state" 2>/dev/null
}

locked() {
    pgrep -f 'quickshell.*Lock\.qml' >/dev/null
}

lock_session() {
    if ! locked; then
        "$LOCK_SH" >/dev/null 2>&1 &
        for _ in {1..20}; do
            locked && break
            sleep 0.1
        done
    fi
}

# Save the exact active profile at lid close (before power-saver
# overwrites /tmp/qs_power_profile). No valid active profile -> no
# marker (and any stale marker is dropped, so nothing bogus restores).
save_current_profile() {
    local cur
    cur=$(cat "$PROFILE_MARKER" 2>/dev/null)
    if valid_profile "$cur"; then
        echo "$cur" > "$SAVED_PROFILE"
    else
        rm -f "$SAVED_PROFILE"
    fi
}

# Restore the profile saved at lid close. The marker is removed ONLY
# after a successful restore; a genuine apply failure keeps it so the
# restore is retried on the next open. Invalid/garbage marker is
# dropped (it can never restore successfully).
restore_profile() {
    local saved
    saved=$(cat "$SAVED_PROFILE" 2>/dev/null)
    if valid_profile "$saved"; then
        if "$APPLY_PROFILE" "$saved"; then
            rm -f "$SAVED_PROFILE"
        fi
    else
        rm -f "$SAVED_PROFILE"
    fi
}

apply_state() {
    local state="$1"
    if [[ "$state" == "closed" ]]; then
        lock_session
        hyprctl eval "hl.dispatch(hl.dsp.dpms({action='off'}))"
        save_current_profile
        "$APPLY_PROFILE" power-saver
    else
        hyprctl eval "hl.dispatch(hl.dsp.dpms({action='on'}))"
        restore_profile
    fi
}

STATE_FILE="$HOME/.cache/qs_lid_state"

sync_state() {
    local now prev
    now=$(read_lid_state)
    case "$now" in
        open|closed) ;;
        *) return ;;
    esac
    prev=$(cat "$STATE_FILE" 2>/dev/null || echo unknown)
    if [ "$now" != "$prev" ]; then
        apply_state "$now"
        echo "$now" > "$STATE_FILE"
    fi
}

# The lid switch is an input device (SW_LID), not a uevent source. Find
# its node dynamically: in /proc/bus/input/devices the paragraph whose
# Name= is "Lid Switch" carries the H: Handlers=eventN line.
find_lid_node() {
    awk '
        BEGIN { RS = ""; FS = "\n" }
        /Lid Switch/ && /Handlers=/ {
            for (i = 1; i <= NF; i++)
                if ($i ~ /Handlers=/) {
                    n = split($i, w, "[ =]")
                    for (j = 1; j <= n; j++)
                        if (w[j] ~ /^event[0-9]+$/) print "/dev/input/" w[j]
                }
        }
    ' /proc/bus/input/devices | head -n 1
}

open_lid_node() {
    local node
    node=$(find_lid_node)
    [ -z "$node" ] && return 1
    exec 3<"$node" 2>/dev/null
}

# Block until one raw input_event arrives on fd 3 (24-byte struct:
# 16-byte timeval, u16 type, u16 code, s32 value; all little-endian).
# This node only ever delivers EV_SW events (type 5, the lid switch),
# so a type byte of 5 means the lid moved; sync_state() then re-reads
# the true state. Returns 1 only on device read failure.
wait_lid_event() {
    local buf b1
    buf=$(dd bs=24 count=1 <&3 2>/dev/null) || return 1
    [ "${#buf}" -lt 24 ] && return 1
    read -r b1 _ < <(printf '%s' "$buf" | od -An -tu1 -j16 -N2)
    [ "${b1:-}" = "5" ]
}

sync_state        # startup reconciliation (transition-only, idempotent)

while true; do
    if open_lid_node; then
        while wait_lid_event; do
            sync_state
        done
    fi
    sleep 0.2      # error-path only: node missing/unreadable/unplugged
done