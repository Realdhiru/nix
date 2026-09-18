#!/usr/bin/env bash
#
# power.sh -- Unified Power, Session, Lock & Lid CLI
#
# Commands:
#   lock           Lock screen via QuickShell Lock.qml with safeguards
#   suspend        Lock and suspend system
#   resume         Post-wake handler (restores display/profile/lock state)
#   lid close|open Laptop lid switch event handler
#   inhibit        Toggle idle inhibition (Coffee mode)
#

set -uo pipefail

CMD="${1:-lock}"
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_QML="$HOME/.config/hypr/scripts/quickshell/Lock.qml"
STATE_FILE="$HOME/.cache/idle_inhibit.pid"

is_locked() {
    pgrep -f 'quickshell.*Lock\.qml' >/dev/null
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: lock
# -----------------------------------------------------------------------------
cmd_lock() {
    if is_locked; then
        exit 0
    fi

    # Reset any stale compositor crash state before launching
    hyprctl dispatch eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1 || true

    export CURRENT_WALLPAPER="$(head -n 1 "$HOME/.cache/current_wallpaper.txt" 2>/dev/null || true)"
    export SYS_KERNEL="$(uname -r 2>/dev/null || true)"
    export SYS_LOAD="$(awk '{print $1, $2, $3}' /proc/loadavg 2>/dev/null || true)"
    export SYS_UPTIME="$(awk '{h=int($1/3600); m=int(($1%3600)/60); printf "%dh %02dm", h, m}' /proc/uptime 2>/dev/null || true)"

    if [ -f "$SCRIPT_DIR/caching.sh" ]; then
        source "$SCRIPT_DIR/caching.sh"
        qs_ensure_cache "lock"
    fi

    local qs_bin="quickshell"
    if ! command -v "$qs_bin" >/dev/null 2>&1; then
        if command -v qs >/dev/null 2>&1; then
            qs_bin="qs"
        else
            exit 1
        fi
    fi

    "$qs_bin" -p "$LOCK_QML"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        hyprctl dispatch eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1 || true
    fi
    exit $exit_code
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: suspend & resume
# -----------------------------------------------------------------------------
cmd_suspend() {
    if ! is_locked; then
        cmd_lock >/dev/null 2>&1 &
    fi
    sleep 1
    systemctl suspend
}

cmd_resume() {
    sleep 1
    if ! is_locked; then
        cmd_lock >/dev/null 2>&1 &
    fi

    if grep -iq "closed" /proc/acpi/button/lid/*/state 2>/dev/null; then
        cmd_lid close
    else
        cmd_lid open
    fi
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: lid
# -----------------------------------------------------------------------------
cmd_lid() {
    local action="${1:-close}"
    case "$action" in
        close)
            if ! is_locked; then
                cmd_lock >/dev/null 2>&1 &
            fi
            sudo /run/current-system/sw/bin/tlp power-saver 2>/dev/null || true
            sleep 1
            hyprctl eval "hl.dispatch(hl.dsp.dpms({action='off'}))"
            ;;
        open)
            sudo /run/current-system/sw/bin/tlp start 2>/dev/null || true
            sleep 0.2
            hyprctl eval "hl.dispatch(hl.dsp.dpms({action='on'}))"
            ;;
        *)
            echo "Usage: power.sh lid {close|open}" >&2
            exit 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: inhibit
# -----------------------------------------------------------------------------
cmd_inhibit() {
    local active=false
    if systemd-inhibit --list 2>/dev/null | grep -q "idle-inhibit-toggle"; then
        active=true
    fi

    if [ "$active" = true ]; then
        if [ -f "$STATE_FILE" ]; then
            kill -- -"$(cat "$STATE_FILE")" 2>/dev/null || true
        fi
        pkill -x systemd-inhibit 2>/dev/null || true
        rm -f "$STATE_FILE"
        notify-send -a "System" -r 9991 -t 1200 -u low -i "appointment-missed" "Coffee mode OFF"
    else
        if [ -f "$STATE_FILE" ]; then
            kill -- -"$(cat "$STATE_FILE")" 2>/dev/null || true
        fi
        pkill -x systemd-inhibit 2>/dev/null || true
        rm -f "$STATE_FILE"
        setsid systemd-inhibit --what=idle --who=idle-inhibit-toggle --why=manual --mode=block sleep infinity &
        echo $! > "$STATE_FILE"
        notify-send -a "System" -r 9991 -t 0 -u low -i "appointment-soon" "Coffee mode ON"
    fi
}

# -----------------------------------------------------------------------------
# ROUTER
# -----------------------------------------------------------------------------
case "$CMD" in
    lock)     cmd_lock "$@" ;;
    suspend)  cmd_suspend "$@" ;;
    resume)   cmd_resume "$@" ;;
    lid)      cmd_lid "$@" ;;
    inhibit)  cmd_inhibit "$@" ;;
    *)
        echo "Usage: power.sh [lock|suspend|resume|lid close|lid open|inhibit]" >&2
        exit 1
        ;;
esac
