#!/usr/bin/env bash
#
# power.sh -- Unified Power, Session, Lock & Lid CLI
#
# Commands:
#   lock           Fast GPU lockscreen via Hyprlock with single-flight safeguards
#   suspend        Lock and suspend system
#   resume         Post-wake handler (restores display/profile/lock state)
#   lid close|open Laptop lid switch event handler
#   inhibit        Toggle idle inhibition (Coffee mode)
#   display        Control display power state (off|on|toggle) via DPMS
#   profile        Hardware power profile switcher (TLP + ACPI platform_profile)
#

set -uo pipefail

CMD="${1:-lock}"
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
STATE_FILE="$DESKTOP_STATE_DIR/power/idle_inhibit.pid"

is_locked() {
    # Check for active hyprlock
    if pgrep -x hyprlock >/dev/null 2>&1; then
        return 0
    fi
    # Match only real quickshell lock processes
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
    # Fast exit: if no lock process exists, skip loginctl session queries entirely
    pgrep -x hyprlock >/dev/null 2>&1 || pgrep -f 'quickshell.*Lock\.qml' >/dev/null 2>&1 || return 0

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
    # 1. Clean orphaned hyprlock processes when session is unlocked
    for pid in $(pgrep -x hyprlock 2>/dev/null || true); do
        [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ] || continue
        start=$(stat -c %Y "/proc/$pid" 2>/dev/null || echo "$now")
        age=$((now - start))
        if [ "$age" -gt 30 ]; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done

    # 2. Clean orphaned quickshell Lock.qml processes
    for pid in $(pgrep -f 'quickshell.*Lock\.qml' 2>/dev/null || true); do
        [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ] || continue
        ps -o args= -p "$pid" 2>/dev/null | grep -qE '(^|/)(\.quickshell-wrapped|quickshell|qs)( |$).*Lock\.qml' || continue
        start=$(stat -c %Y "/proc/$pid" 2>/dev/null || echo "$now")
        age=$((now - start))
        if [ "$age" -gt 30 ]; then
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

    reap_stray_locks

    if is_locked; then
        flock -u 9 2>/dev/null || true
        exec 9>&- 2>/dev/null || true
        exit 0
    fi

    if command -v hyprlock >/dev/null 2>&1; then
        flock -u 9 2>/dev/null || true
        exec 9>&- 2>/dev/null || true
        exec hyprlock
    fi

    # Reset any stale compositor crash state before launching
    hyprctl eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1 || true

    local state_wall_dir="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}/wallpaper"
    local wp="$(head -n 1 "$state_wall_dir/current_wallpaper.txt" 2>/dev/null || true)"
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
        if [ $code -ne 0 ]; then
            echo "[power.sh $(date '+%Y-%m-%d %H:%M:%S')] Lock process exited with code $code. Executing emergency clear_crashed_lockscreen failsafe." >> "$crash_log"
            hyprctl eval 'hl.clear_crashed_lockscreen()' >/dev/null 2>&1 || true
        fi
    }
    trap cleanup_lock EXIT INT TERM HUP

    "$qs_bin" -p "$LOCK_QML" 2> >(tee -a "$crash_log" >&2)
    local exit_code=$?
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
    systemctl suspend
}

cmd_resume() {
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
            # 1. Turn off OLED display immediately
            hyprctl eval "hl.dispatch(hl.dsp.dpms({action='off'}))" >/dev/null 2>&1 || true

            # 2. Save and turn off keyboard backlight
            local kbd_val
            kbd_val=$(brightnessctl --device='asus::kbd_backlight' get 2>/dev/null || echo "0")
            echo "$kbd_val" > /run/user/${UID:-1000}/saved_kbd_backlight 2>/dev/null || true
            brightnessctl --device='asus::kbd_backlight' set 0 >/dev/null 2>&1 || true

            # 3. Pause CAVA audio FFT processing to eliminate wasted audio analysis cycles
            pkill -STOP -f "cava.*cava_topbar.conf" 2>/dev/null || true

            # 4. Turn off Bluetooth radio IF no device is actively connected AND it was powered on
            if ! bluetoothctl devices Connected 2>/dev/null | grep -q "Device"; then
                if timeout 0.5 bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
                    touch /run/user/${UID:-1000}/lid_bt_turned_off 2>/dev/null || true
                    rfkill block bluetooth 2>/dev/null || true
                fi
            fi

            # 5. Apply TLP power-saver (caps package power <10W while keeping balanced fan profile)
            sudo tlp power-saver >/dev/null 2>&1 &
            ;;
        open)
            # 1. Immediate DPMS wake
            hyprctl eval "hl.dispatch(hl.dsp.dpms({action='on'}))" >/dev/null 2>&1 || true

            # 2. Restore peripherals and profiles asynchronously in background (zero display delay)
            (
                # Resume CAVA audio visualizer
                pkill -CONT -f "cava.*cava_topbar.conf" 2>/dev/null || true

                # Restore keyboard backlight if previously active
                if [ -f "/run/user/${UID:-1000}/saved_kbd_backlight" ]; then
                    local prev_kbd
                    prev_kbd=$(cat "/run/user/${UID:-1000}/saved_kbd_backlight" 2>/dev/null || echo "0")
                    if [ -n "$prev_kbd" ] && [ "$prev_kbd" -gt 0 ] 2>/dev/null; then
                        brightnessctl --device='asus::kbd_backlight' set "$prev_kbd" >/dev/null 2>&1 || true
                    fi
                    rm -f "/run/user/${UID:-1000}/saved_kbd_backlight" 2>/dev/null || true
                fi

                # Restore Bluetooth if it was turned off by lid close
                if [ -f "/run/user/${UID:-1000}/lid_bt_turned_off" ]; then
                    rfkill unblock bluetooth 2>/dev/null || true
                    rm -f "/run/user/${UID:-1000}/lid_bt_turned_off" 2>/dev/null || true
                fi

                # Restore TLP profile
                sudo tlp start >/dev/null 2>&1 || true
            ) >/dev/null 2>&1 &
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
    local mode_ctl="$SCRIPT_DIR/mode_ctl.sh"
    [ -f "$mode_ctl" ] || mode_ctl="$HOME/.config/hypr/scripts/mode_ctl.sh"

    local modes_json="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}/modes/modes.json"
    local is_running="false"
    if [ -s "$modes_json" ]; then
        is_running=$(jq -r '.active.coffee // false' "$modes_json" 2>/dev/null || echo "false")
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
            if [ "$is_running" = "true" ]; then
                echo "active"
                exit 0
            else
                echo "inactive"
                exit 1
            fi
            ;;
        toggle|*)
            if [ "$is_running" = "true" ]; then
                do_enable=false
            else
                do_enable=true
            fi
            ;;
    esac

    # Dispatch notification immediately (<10ms) before executing mode switch
    if [ "$do_enable" = true ]; then
        notify-send -a "Power" -r 9991 -t 1200 -u low -i "appointment-soon" "Coffee ON"
    else
        notify-send -a "Power" -r 9991 -t 1200 -u low -i "appointment-missed" "Coffee OFF"
    fi

    bash "$mode_ctl" set coffee "$do_enable" 2>/dev/null || true
}

cmd_profile() {
    local prof="${1:-balanced}"
    local tlp_cmd="balanced"
    local acpi_prof="balanced"
    local asus_prof="Balanced"

    case "$prof" in
        performance)
            tlp_cmd="performance"
            acpi_prof="performance"
            asus_prof="Performance"
            ;;
        power-saver|quiet)
            tlp_cmd="power-saver"
            acpi_prof="low-power"
            asus_prof="Quiet"
            ;;
        balanced|*)
            prof="balanced"
            tlp_cmd="balanced"
            acpi_prof="balanced"
            asus_prof="Balanced"
            ;;
    esac

    # 1. Universal TLP hardware authority
    if command -v tlp >/dev/null 2>&1; then
        sudo tlp "$tlp_cmd" >/dev/null 2>&1 || true
    fi

    # 2. Universal Linux Kernel ACPI Platform Profile (/sys/firmware/acpi/platform_profile)
    # Supported natively by ThinkPad, Dell, HP, Framework, ASUS, Lenovo, etc.
    if [ -w /sys/firmware/acpi/platform_profile ]; then
        echo "$acpi_prof" > /sys/firmware/acpi/platform_profile 2>/dev/null || true
    fi

    # 3. Dynamic vendor hardware CLI hook (dynamically probed; non-ASUS machines skip seamlessly)
    if command -v asusctl >/dev/null 2>&1; then
        asusctl profile set "$asus_prof" >/dev/null 2>&1 || true
    fi

    # 4. Atomic profile state sync
    mkdir -p "$DESKTOP_STATE_DIR/power"
    echo "$prof" > "$DESKTOP_STATE_DIR/power/profile.tmp" && mv -f "$DESKTOP_STATE_DIR/power/profile.tmp" "$DESKTOP_STATE_DIR/power/profile"
    local state_ctl="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
    [ ! -x "$state_ctl" ] && state_ctl="$HOME/nix/dotfiles/hypr/scripts/quickshell/state_ctl.sh"
    if [ -x "$state_ctl" ]; then
        bash "$state_ctl" set power.profile "$prof" >/dev/null 2>&1 || true
    fi

    # 5. Modes Engine SSOT sync (only if not called internally by mode_ctl.sh)
    if [ "${CALLER_IS_MODE_CTL:-false}" != "true" ]; then
        notify-send -a "Power" -u low "${prof^} Mode" 2>/dev/null || true
        local mode_ctl="$SCRIPT_DIR/mode_ctl.sh"
        [ -f "$mode_ctl" ] || mode_ctl="$HOME/.config/hypr/scripts/mode_ctl.sh"
        if [ "$prof" = "power-saver" ] || [ "$prof" = "quiet" ]; then
            bash "$mode_ctl" set power-saver true 2>/dev/null || true
        else
            bash "$mode_ctl" set power-saver false 2>/dev/null || true
        fi
    fi
}

# -----------------------------------------------------------------------------
# SUBCOMMAND: display (DPMS display power control)
# -----------------------------------------------------------------------------
cmd_display() {
    local action="${1:-toggle}"
    local marker="/run/user/${UID:-1000}/display_dpms_off"

    case "$action" in
        off)
            touch "$marker" 2>/dev/null || true
            brightnessctl -sd asus::kbd_backlight set 0 >/dev/null 2>&1 || true
            hyprctl eval "hl.dispatch(hl.dsp.dpms({action='off'}))" >/dev/null 2>&1 || true
            ;;
        on)
            rm -f "$marker" 2>/dev/null || true
            hyprctl eval "hl.dispatch(hl.dsp.dpms({action='on'}))" >/dev/null 2>&1 || true
            brightnessctl -rd asus::kbd_backlight >/dev/null 2>&1 || true
            ;;
        toggle)
            local status
            status=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].dpmsStatus // true')
            if [ "$status" = "false" ] || [ -f "$marker" ]; then
                cmd_display on
            else
                cmd_display off
            fi
            ;;
        status)
            hyprctl monitors -j 2>/dev/null | jq -r '.[0].dpmsStatus // true'
            ;;
        *)
            echo "Usage: power.sh display {toggle|off|on|status}" >&2
            exit 1
            ;;
    esac
}

cmd_battery_audit() {
    local audit_script="$SCRIPT_DIR/battery_audit.sh"
    [ -x "$audit_script" ] || audit_script="$HOME/.config/hypr/scripts/battery_audit.sh"
    exec bash "$audit_script" "${1:-report}"
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
    display)  cmd_display "$@" ;;
    dpms)     cmd_display "$@" ;;
    profile)  cmd_profile "$@" ;;
    battery-audit|audit) cmd_battery_audit "$@" ;;
    *)
        echo "Usage: power.sh [lock|suspend|resume|lid close|lid open|inhibit|display <off|on|toggle>|profile <performance|balanced|power-saver>|battery-audit [report|status|start|stop|reset]]" >&2
        exit 1
        ;;
esac
