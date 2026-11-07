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
# Bound all compositor IPC paths, including lid/display handlers.
hyprctl() { timeout 3 command hyprctl "$@"; }

keyboard_backlight_device() {
    local path
    for path in /sys/class/leds/*kbd_backlight/brightness; do
        [ -e "$path" ] || continue
        path="${path%/brightness}"
        printf '%s\n' "${path##*/}"
        return 0
    done
    return 1
}

cmd_keyboard_backlight() {
    local action="${1:-off}" device
    device=$(keyboard_backlight_device) || return 0
    case "$action" in
        off) brightnessctl --device="$device" -s set 0 >/dev/null 2>&1 || true ;;
        restore) brightnessctl --device="$device" -r >/dev/null 2>&1 || true ;;
        *) echo "Usage: power.sh keyboard-backlight {off|restore}" >&2; return 2 ;;
    esac
}

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
    local wp
    wp="$(head -n 1 "$state_wall_dir/current_wallpaper.txt" 2>/dev/null || true)"
    export CURRENT_WALLPAPER="$wp"
    export CURRENT_WALLPAPER_THUMB=""
    if [[ "$wp" =~ \.(mp4|mkv|mov|webm)$ ]]; then
        local base
        base="$(basename "$wp")"
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
        if [ "$code" -ne 0 ]; then
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

            # 2. Save and turn off any detected keyboard backlight.
            local kbd_device kbd_val
            kbd_device=$(keyboard_backlight_device 2>/dev/null || true)
            if [ -n "$kbd_device" ]; then
                kbd_val=$(brightnessctl --device="$kbd_device" get 2>/dev/null || echo "0")
                printf '%s\n%s\n' "$kbd_device" "$kbd_val" > "/run/user/${UID:-1000}/saved_kbd_backlight" 2>/dev/null || true
                brightnessctl --device="$kbd_device" set 0 >/dev/null 2>&1 || true
            fi

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
                    local -a saved_kbd=()
                    mapfile -t saved_kbd < "/run/user/${UID:-1000}/saved_kbd_backlight" 2>/dev/null || true
                    local prev_kbd_device prev_kbd
                    if [ "${#saved_kbd[@]}" -gt 1 ]; then
                        prev_kbd_device="${saved_kbd[0]}"
                        prev_kbd="${saved_kbd[1]}"
                    else
                        prev_kbd_device=$(keyboard_backlight_device 2>/dev/null || true)
                        prev_kbd="${saved_kbd[0]:-0}"
                    fi
                    if [ -n "$prev_kbd_device" ] && [ -n "$prev_kbd" ] && [ "$prev_kbd" -gt 0 ] 2>/dev/null; then
                        brightnessctl --device="$prev_kbd_device" set "$prev_kbd" >/dev/null 2>&1 || true
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

    if bash "$mode_ctl" set coffee "$do_enable"; then
        if [ "$do_enable" = true ]; then
            notify-send -a "Power" -r 9991 -t 1200 -u low -i "appointment-soon" "Coffee ON"
        else
            notify-send -a "Power" -r 9991 -t 1200 -u low -i "appointment-missed" "Coffee OFF"
        fi
    else
        notify-send -a "Power" -u critical "Failed"
        return 1
    fi
}

cmd_profile() {
    local prof="${1:-balanced}"
    local tlp_cmd="balanced"

    case "$prof" in
        performance)
            tlp_cmd="performance"
            ;;
        power-saver|quiet)
            prof="power-saver"
            tlp_cmd="power-saver"
            ;;
        balanced|*)
            prof="balanced"
            tlp_cmd="balanced"
            ;;
    esac

    mkdir -p "$DESKTOP_STATE_DIR/power"
    exec 7>"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/desktop-power.lock"
    if ! flock -w 10 7; then
        echo "power.sh: another profile change held the lock for 10 seconds" >&2
        return 1
    fi

    local applied
    applied="$(cat "$DESKTOP_STATE_DIR/power/applied" 2>/dev/null || true)"

    # 1. Hardware TLP profile (invisible modeset), skip if already applied
    local has_battery=false type_path supply_type
    for type_path in /sys/class/power_supply/*/type; do
        [ -r "$type_path" ] || continue
        read -r supply_type < "$type_path"
        if [ "$supply_type" = "Battery" ]; then
            has_battery=true
            break
        fi
    done

    if [ "$has_battery" = "true" ] && [ "$applied" != "$prof" ]; then
        if ! command -v tlp >/dev/null 2>&1 || ! timeout 15 sudo tlp "$tlp_cmd" 7>&-; then
            notify-send -a "Power" -u critical "Profile Failed" 2>/dev/null || true
            return 1
        fi
        printf '%s\n' "$prof" > "$DESKTOP_STATE_DIR/power/applied"
    elif [ "$has_battery" = "false" ]; then
        echo "power.sh: no battery detected; skipping the optional TLP hardware profile" >&2
    fi

    # 2. Atomic state sync
    printf '%s\n' "$prof" > "$DESKTOP_STATE_DIR/power/profile.tmp" && \
        mv -f "$DESKTOP_STATE_DIR/power/profile.tmp" "$DESKTOP_STATE_DIR/power/profile"
    local state_ctl="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
    [ ! -x "$state_ctl" ] && state_ctl="${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/hypr/scripts/quickshell/state_ctl.sh"
    if [ -x "$state_ctl" ]; then
        bash "$state_ctl" set power.profile "$prof" 7>&- || {
            echo "power.sh: failed to persist power profile state" >&2
            return 1
        }
    fi

    # Never hold desktop-power.lock while acquiring mode_ctl's .modes.lock.
    # mode_ctl may call back here while holding .modes.lock, so nested locks
    # in the opposite order deadlock during concurrent profile/mode changes.
    flock -u 7
    exec 7>&-

    # 3. Appearance + Modes Engine SSOT sync (skip profile recursion, suppress wallpaper transition)
    if [ "${CALLER_IS_MODE_CTL:-false}" != "true" ]; then
        local mode_ctl="$SCRIPT_DIR/mode_ctl.sh"
        [ -f "$mode_ctl" ] || mode_ctl="$HOME/.config/hypr/scripts/mode_ctl.sh"
        local want=false
        [ "$prof" = "power-saver" ] && want=true
        if [ -x "$mode_ctl" ]; then
            MODE_CTL_NO_PROFILE=1 WALL_TRANSITION=none \
                timeout 10 bash "$mode_ctl" set power-saver "$want" >/dev/null 2>&1 || {
                    echo "power.sh: failed to synchronize power-saver mode" >&2
                    return 1
                }
        fi
    fi

    # 4. Monitor refresh rate modeset LAST: ensures all shaders/backgrounds ready, single blink
    local refresh_script="${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/hypr/scripts/refresh_monitor.sh"
    [ -x "$refresh_script" ] || refresh_script="$HOME/.config/hypr/scripts/refresh_monitor.sh"
    if [ -x "$refresh_script" ]; then
        timeout 5 "$refresh_script" || echo "power.sh: monitor refresh policy could not be applied" >&2
    fi
}

cmd_auto() {
    local on_ac=0 p cur
    for p in /sys/class/power_supply/*/online; do
        if [ -f "$p" ] && [ "$(cat "$p" 2>/dev/null)" = "1" ]; then
            on_ac=1
            break
        fi
    done

    cur="$(cat "$DESKTOP_STATE_DIR/power/profile" 2>/dev/null || echo balanced)"
    if [ "$on_ac" -eq 1 ]; then
        cmd_profile performance
    elif [ "$cur" = "performance" ]; then
        cmd_profile balanced
    else
        # On battery, keep power-saver or balanced as set by user
        cmd_profile "$cur"
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
            cmd_keyboard_backlight off
            hyprctl eval "hl.dispatch(hl.dsp.dpms({action='off'}))" >/dev/null 2>&1 || true
            ;;
        on)
            rm -f "$marker" 2>/dev/null || true
            hyprctl eval "hl.dispatch(hl.dsp.dpms({action='on'}))" >/dev/null 2>&1 || true
            cmd_keyboard_backlight restore
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
    keyboard-backlight) cmd_keyboard_backlight "$@" ;;
    dpms)     cmd_display "$@" ;;
    profile)  cmd_profile "$@" ;;
    auto)     cmd_auto "$@" ;;
    battery-audit|audit) cmd_battery_audit "$@" ;;
    *)
        echo "Usage: power.sh [lock|suspend|resume|lid close|lid open|inhibit|display <off|on|toggle>|keyboard-backlight <off|restore>|profile <performance|balanced|power-saver>|auto|battery-audit [report|status|start|stop|reset]]" >&2
        exit 1
        ;;
esac
