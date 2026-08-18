#!/usr/bin/env bash
#
# lid-monitor.sh -- event-driven lid watcher. NEVER suspends (hard user
# requirement: logind HandleLidSwitch stays "ignore"; suspend is manual
# via Shift+Esc only).
#
# Lid close -> lock session (existing Quickshell Lock.qml lock, same
# mechanism hypridle uses), then display off, then power-saver via
# apply_profile.sh. The DPMS action is a DIRECT compositor-socket call:
# it is intentionally NOT idle-aware, so Coffee Mode
# (systemd-inhibit --what=idle, which only gates hypridle's idle
# detection) can never prevent or delay it.
# Lid open  -> display on ONLY. The power profile is left untouched:
# power-saver persists after opening (no save/restore of any profile;
# no power-profile transition on the open path).
#
# Event source is udevadm (kernel uevents for the ACPI lid device,
# PNP0C0D). Each monitor run is bounded by `timeout 10`; the reconnect
# loop restarts it and re-reads the ACPI lid state at every restart, so
# a missed (or missing) uevent is caught at most 10s later. That watchdog
# only acts on state TRANSITIONS (see sync_state), so the regular re-sync
# is idempotent and never re-applies actions.

set -uo pipefail

LID=$(echo /proc/acpi/button/lid/LID*)
APPLY_PROFILE="$HOME/.config/hypr/scripts/quickshell/battery/apply_profile.sh"
LOCK_SH="$HOME/.config/hypr/scripts/lock.sh"

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

apply_state() {
    local state="$1"
    if [[ "$state" == "closed" ]]; then
        lock_session
        hyprctl eval "hl.dispatch(hl.dsp.dpms({action='off'}))"
        "$APPLY_PROFILE" power-saver
    else
        hyprctl eval "hl.dispatch(hl.dsp.dpms({action='on'}))"
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

# Event loop: kernel uevents for the ACPI lid device (PNP0C0D; it lives in
# subsystem "platform", its input child in subsystem "input"). A subsystem
# filter is deliberately NOT used -- there is no "button" subsystem on this
# kernel, so `--subsystem-match=button` matched nothing and silently kept
# the watcher deaf. `timeout 10` bounds each udevadm run, and sync_state()
# re-reads the ACPI lid state at every restart, so a missed or absent
# uevent is caught within 10s (only on transitions: idempotent).
run_monitor() {
    sync_state
    timeout 10 udevadm monitor --kernel 2>/dev/null | while read -r line; do
        case "$line" in
            *PNP0C0D*|*lid*|*button*) sync_state ;;
        esac
    done
}

while true; do
    run_monitor
    sleep 1
done
