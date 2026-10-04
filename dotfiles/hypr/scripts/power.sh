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
    # Match only real quickshell lock processes, never shells/scripts that
    # merely mention the path (test commands, agents, wrappers) — a bare
    # pgrep -f false-positives on those and silently swallows lock attempts.
    local pid
    for pid in $(pgrep -f 'quickshell.*Lock\.qml' 2>/dev/null || true); do
        [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ] || continue
        if ps -o args= -p "$pid" 2>/dev/null | grep -qE '(^|/)(\.quickshell-wrapped|quickshell|qs)( |$).*Lock\.qml'; then
            return 0
        fi
    done
    return 1
}

# Reap definitionally-stray lock processes: a legitimate lock ALWAYS holds
# the session lock (LockedHint=yes), so a Lock.qml older than 45s with the
# session unlocked can only be a failed acquisition left idling (it blocks
# PAM-lessly forever and poisons is_locked). Kill only those; young
# processes may still be acquiring, live ones are untouched.
reap_stray_locks() {
    local sess hint now start age pid
    sess="${XDG_SESSION_ID:-}"
    if [ -z "$sess" ]; then
        sess=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$(id -un 2>/dev/null)" '$3==u && $4=="seat0" {print $1; exit}' || true)
        [ -n "$sess" ] || sess=$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$(id -un 2>/dev/null)" '$3==u {print $1; exit}' || true)
    fi
    [ -n "$sess" ] || return 0
    hint=$(loginctl show-session "$sess" -p LockedHint 2>/dev/null | cut -d= -f2 || true)
    [ "$hint" = "no" ] || return 0
    now=$(date +%s)
    for pid in $(pgrep -f 'quickshell.*Lock\.qml' 2>/dev/null || true); do
        [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ] || continue
        ps -o args= -p "$pid" 2>/dev/null | grep -qE '(^|/)(\.quickshell-wrapped|quickshell|qs)( |$).*Lock\.qml' || continue
        start=$(stat -c %Y "/proc/$pid" 2>/dev/null || echo "$now")
        age=$((now - start))
        if [ "$age" -gt 45 ]; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: lock
# -----------------------------------------------------------------------------
cmd_lock() {
    # Single-flight: two near-simultaneous triggers (keybind + hypridle,
    # double-press) used to both pass is_locked, spawn twice, and leave the
    # loser invisibly stuck with no session lock — poisoning every later
    # attempt. Non-blocking: a contender in flight means lock is imminent.
    LOCK_GUARD="$HOME/.cache/quickshell/lock_guard.lock"
    mkdir -p "$(dirname "$LOCK_GUARD")"
    exec 9>"$LOCK_GUARD" 2>/dev/null || true
    if ! flock -n 9 2>/dev/null; then
        exit 0
    fi

    if is_locked; then
        flock -u 9 2>/dev/null || true
        exec 9>&- 2>/dev/null || true
        exit 0
    fi

    reap_stray_locks

    # Reset any stale compositor crash state before launching
    hyprctl eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1 || true

    # Take live desktop screenshot for frosted glass lock mode
    local lock_snap="/tmp/lock_screenshot.jpg"
    rm -f "$lock_snap" 2>/dev/null || true
    if command -v grim >/dev/null 2>&1; then
        grim -t jpeg -q 30 "$lock_snap" 2>/dev/null || true
    fi

    if [ -s "$lock_snap" ]; then
        export CURRENT_WALLPAPER="$lock_snap"
        export CURRENT_WALLPAPER_THUMB=""
    else
        local wp="$(head -n 1 "$HOME/.cache/current_wallpaper.txt" 2>/dev/null || true)"
        export CURRENT_WALLPAPER="$wp"
        export CURRENT_WALLPAPER_THUMB=""
        if [[ "$wp" =~ \.(mp4|mkv|mov|webm)$ ]]; then
            local base="$(basename "$wp")"
            if [ -f "/tmp/thumb_${base}.jpg" ]; then
                export CURRENT_WALLPAPER_THUMB="/tmp/thumb_${base}.jpg"
            elif [ -f "$HOME/.cache/quickshell/wallpaper_picker/thumbs/${base}.jpg" ]; then
                export CURRENT_WALLPAPER_THUMB="$HOME/.cache/quickshell/wallpaper_picker/thumbs/${base}.jpg"
            fi
        fi
    fi

    local qs_bin="quickshell"
    if ! command -v "$qs_bin" >/dev/null 2>&1; then
        if command -v qs >/dev/null 2>&1; then
            qs_bin="qs"
        else
            exit 1
        fi
    fi

    local crash_log="/run/user/${UID:-1000}/quickshell/lock_crash.log"
    mkdir -p "$(dirname "$crash_log")"

    # Watchdog cleanup trap: clear crashed session lock if process terminates abnormally
    cleanup_lock() {
        local code=$?
        rm -f "$lock_snap" 2>/dev/null || true
        if [ $code -ne 0 ]; then
            echo "[power.sh $(date '+%Y-%m-%d %H:%M:%S')] Lock process exited with code $code. Executing emergency clear_crashed_lockscreen failsafe." >> "$crash_log"
            hyprctl eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1 || true
        fi
    }
    trap cleanup_lock EXIT INT TERM HUP

    "$qs_bin" -p "$LOCK_QML" 2> >(tee -a "$crash_log" >&2)
    local exit_code=$?
    rm -f "$lock_snap" 2>/dev/null || true
    if [ $exit_code -ne 0 ]; then
        hyprctl eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1 || true
    fi
    trap - EXIT INT TERM HUP
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
# SUBCOMMAND: inhibit (Coffee mode)
# -----------------------------------------------------------------------------
cmd_inhibit() {
    local target="${1:-toggle}"
    local state_ctl="$SCRIPT_DIR/quickshell/state_ctl.sh"

    local is_running=false
    if systemctl --user is-active --quiet coffee-mode 2>/dev/null || systemd-inhibit --list 2>/dev/null | grep -q "idle-inhibit-toggle"; then
        is_running=true
    fi

    local do_enable=false
    case "$target" in
        on|enable|start)
            do_enable=true
            ;;
        off|disable|stop)
            do_enable=false
            ;;
        status)
            if [ "$is_running" = true ]; then
                echo "active"
                exit 0
            else
                echo "inactive"
                exit 1
            fi
            ;;
        toggle|*)
            if [ "$is_running" = true ]; then
                do_enable=false
            else
                do_enable=true
            fi
            ;;
    esac

    if [ "$do_enable" = true ]; then
        systemctl --user stop coffee-mode 2>/dev/null || true
        pkill -f "idle-inhibit-toggle" 2>/dev/null || true
        rm -f "$STATE_FILE"

        systemd-run --user --unit=coffee-mode systemd-inhibit --what=idle:sleep --who=idle-inhibit-toggle --why="Coffee mode (idle inhibit)" --mode=block sleep infinity >/dev/null 2>&1

        if [ -x "$state_ctl" ]; then
            "$state_ctl" set modes.coffee true 2>/dev/null || true
        fi

        notify-send -a "System" -r 9991 -t 1200 -u low -i "appointment-soon" "Coffee mode ON"
    else
        systemctl --user stop coffee-mode 2>/dev/null || true
        pkill -f "idle-inhibit-toggle" 2>/dev/null || true
        rm -f "$STATE_FILE"

        if [ -x "$state_ctl" ]; then
            "$state_ctl" set modes.coffee false 2>/dev/null || true
        fi

        notify-send -a "System" -r 9991 -t 1200 -u low -i "appointment-missed" "Coffee mode OFF"
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
