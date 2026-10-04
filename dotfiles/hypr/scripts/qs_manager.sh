#!/usr/bin/env bash

# Strict execution environment
set -uo pipefail

# -----------------------------------------------------------------------------
# GLOBAL VARS
# -----------------------------------------------------------------------------
SCRIPTS_DIR="$HOME/.config/hypr/scripts/quickshell"
SHELL_QML_PATH="$SCRIPTS_DIR/Shell.qml"

# Resolve the correct NixOS binary dynamically
QS_BIN=""
if command -v quickshell >/dev/null 2>&1; then
    QS_BIN="quickshell"
elif command -v qs >/dev/null 2>&1; then
    QS_BIN="qs"
else
    # Failsafe abort if the binary isn't in PATH
    exit 1
fi

# -----------------------------------------------------------------------------
# FAST PATH: WORKSPACE SWITCHING
# Must be first — before any sourcing, caching, or pgrep.
# -----------------------------------------------------------------------------
ACTION="${1:-}"
TARGET="${2:-}"
SUBTARGET="${3:-}"

# -----------------------------------------------------------------------------
# ORPHAN REAPER: SIGKILLing quickshell (below) orphans its stateless
# follower processes (PPID 1) because QML onDestruction never runs.
# Fresh instances respawn everything, so reaping ONLY PPID-1 strays is
# always safe — live children (PPID=quickshell) are never touched.
# Patterns are exact full-command matches: never bare names (a bare
# "wl-paste" or "playerctl" pattern would hit clipboard owners / daemons).
# -----------------------------------------------------------------------------
reap_qs_orphans() {
    local pid ppid
    for pid in $(pgrep -f "playerctl -a --follow" 2>/dev/null || true) $(pgrep -f "cava -p .*cava_topbar.conf" 2>/dev/null || true) $(pgrep -f "udevadm monitor --subsystem-match" 2>/dev/null || true); do
        [ -n "$pid" ] || continue
        ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ' || true)
        if [ "$ppid" = "1" ]; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
}

if [[ "$ACTION" == "reload" ]]; then
    pkill -9 -f "quickshell" 2>/dev/null || true
    pkill -9 -f "\.quickshell-wra" 2>/dev/null || true
    reap_qs_orphans
    sleep 0.3
    hyprctl eval "hl.dispatch(hl.dsp.exec_cmd('$QS_BIN -p $SHELL_QML_PATH'))" >/dev/null 2>&1 || (nohup "$QS_BIN" -p "$SHELL_QML_PATH" >/dev/null 2>&1 & disown)
    exit 0
fi

if [[ "$ACTION" == "toggle" && "$TARGET" == "quickshell" ]]; then
    if pgrep -f "Shell.qml" >/dev/null || pgrep -x quickshell >/dev/null || pgrep -f "\.quickshell-wra" >/dev/null; then
        pkill -9 -f "quickshell" 2>/dev/null || true
        pkill -9 -f "\.quickshell-wra" 2>/dev/null || true
        reap_qs_orphans
        notify-send -a "QuickShell" -u low "QuickShell OFF" 2>/dev/null || true
    else
        reap_qs_orphans
        hyprctl eval "hl.dispatch(hl.dsp.exec_cmd('$QS_BIN -p $SHELL_QML_PATH'))" >/dev/null 2>&1 || (nohup "$QS_BIN" -p "$SHELL_QML_PATH" >/dev/null 2>&1 & disown)
        notify-send -a "QuickShell" -u low "QuickShell ON" 2>/dev/null || true
    fi
    exit 0
fi

if [[ "$ACTION" == "toggle" && "$TARGET" == "topbar" ]]; then
    "$QS_BIN" ipc -p "$SHELL_QML_PATH" call main handleCommand "toggle" "topbar" "" >/dev/null 2>&1 || "$QS_BIN" ipc -p "$SHELL_QML_PATH" call topbar toggle >/dev/null 2>&1
    exit 0
fi

if [[ "$ACTION" == "position" && "$TARGET" == "topbar" ]]; then
    "$QS_BIN" ipc -p "$SHELL_QML_PATH" call main handleCommand "position" "topbar" "$SUBTARGET" >/dev/null 2>&1 || "$QS_BIN" ipc -p "$SHELL_QML_PATH" call topbar setPosition "$SUBTARGET" >/dev/null 2>&1
    exit 0
fi

if [[ "$ACTION" == "autohide" || ("$ACTION" == "toggle" && "$TARGET" == "autohide") ]]; then
    "$QS_BIN" ipc -p "$SHELL_QML_PATH" call main handleCommand "autohide" "" "" >/dev/null 2>&1
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" || "$ACTION" == "close" ]]; then
    "$QS_BIN" ipc -p "$SHELL_QML_PATH" call main handleCommand "$ACTION" "$TARGET" "$SUBTARGET" >/dev/null 2>&1
    exit 0
fi


if [[ "$ACTION" != "close" && "$ACTION" != "open" && "$ACTION" != "toggle" && "$ACTION" =~ ^[0-9a-zA-Z:-]+$ ]]; then
    # Send IPC command directly to Main.qml via Quickshell's native IPC handler
    "$QS_BIN" ipc -p "$SHELL_QML_PATH" call main handleCommand "close" "" "" >/dev/null 2>&1

    if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
        WS_ARG="$ACTION"
    else
        WS_ARG="'$ACTION'"
    fi

    if [[ "$TARGET" == "move" ]]; then
        hyprctl eval "hl.dispatch(hl.dsp.window.move({ workspace = $WS_ARG }))" >/dev/null 2>&1
    else
        hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = $WS_ARG }))" >/dev/null 2>&1
    fi
    exit 0
fi

# -----------------------------------------------------------------------------
# SLOW PATH: Everything below only runs for non-workspace actions
# -----------------------------------------------------------------------------

source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"

qs_ensure_cache "workspaces"
qs_ensure_cache "network"
qs_ensure_cache "wallpaper_picker"
qs_ensure_cache "music"

BT_PID_FILE="$QS_RUN_DIR/bt_scan_pid"
BT_SCAN_LOG="$QS_LOG_DIR/bt_scan.log"
SRC_DIR="${WALLPAPER_DIR:-${srcdir:-$HOME/Pictures/Wallpapers}}"
THUMB_DIR="$QS_CACHE_WALLPAPER_PICKER/thumbs"
PREP_LOCK="$QS_RUN_DIR/wallpaper_prep.lock"

export MAGICK_THREAD_LIMIT=1

QS_NETWORK_CACHE="$QS_CACHE_NETWORK"
mkdir -p "$QS_NETWORK_CACHE" "$THUMB_DIR"

NETWORK_MODE_FILE="$QS_NETWORK_CACHE/mode"

MANIFEST="$THUMB_DIR/.manifest"

# -----------------------------------------------------------------------------
# ZOMBIE WATCHDOG
# -----------------------------------------------------------------------------

# Safely catch wrapped NixOS binaries without regex misses, with a lock to prevent race conditions
(
    flock -n 200 || exit 0
    if ! pgrep -f "Shell.qml" >/dev/null; then
        pkill -9 quickshell 2>/dev/null || true
        pkill -9 -f "\.quickshell-wra" 2>/dev/null || true
        "$QS_BIN" -p "$SHELL_QML_PATH" >/dev/null 2>&1 &
        disown
    fi
) 200>"/tmp/qs_watchdog.lock"

# -----------------------------------------------------------------------------
# HELPERS
# -----------------------------------------------------------------------------
build_manifest() {
    find "$THUMB_DIR" -maxdepth 1 -type f ! -name '.source_dir' ! -name '.manifest' \
        -printf "%f\n" | sort > "$MANIFEST"
}

handle_wallpaper_prep() {
    mkdir -p "$THUMB_DIR"

    (
        if [ -f "$PREP_LOCK" ]; then
            if kill -0 "$(cat "$PREP_LOCK")" 2>/dev/null; then
                exit 0
            fi
        fi
        echo $BASHPID > "$PREP_LOCK"

        if [ -x "$HOME/.config/wallpaper/wallpaper.sh" ]; then
            bash "$HOME/.config/wallpaper/wallpaper.sh" thumb >/dev/null 2>&1
        elif command -v wallpaper >/dev/null 2>&1; then
            wallpaper thumb >/dev/null 2>&1
        fi

        rm -f "$PREP_LOCK"
    ) </dev/null >/dev/null 2>&1 &
}

# Controlled scan initialization relying on internal daemons rather than an infinite shell lock
handle_network_prep() {
    echo "" > "$BT_SCAN_LOG"
    timeout 30 bluetoothctl scan on > "$BT_SCAN_LOG" 2>&1 &
    echo $! > "$BT_PID_FILE"
    nmcli device wifi rescan >/dev/null 2>&1 &
}

# -----------------------------------------------------------------------------
# IPC ROUTING
# -----------------------------------------------------------------------------
if [[ "$ACTION" == "close" ]]; then
    "$QS_BIN" ipc -p "$SHELL_QML_PATH" call main handleCommand "close" "" "" >/dev/null 2>&1

    if [[ "$TARGET" == "network" || "$TARGET" == "all" || -z "$TARGET" ]]; then
        if [ -f "$BT_PID_FILE" ]; then
            kill "$(cat "$BT_PID_FILE")" 2>/dev/null
            rm -f "$BT_PID_FILE"
        fi
    fi
    exit 0
fi

if [[ "$ACTION" == "open" || "$ACTION" == "toggle" ]]; then

    if [[ "$TARGET" == "calendar" ]]; then
        if [ ! -s "$HOME/nix/dotfiles/secrets/openweather.json" ]; then
            TARGET="weather_setup"
        fi
    fi

    if [[ "$TARGET" == "network" ]]; then
        handle_network_prep
        [[ -n "$SUBTARGET" ]] && { echo "$SUBTARGET" > "$NETWORK_MODE_FILE"; bash "$SCRIPTS_DIR/state_ctl.sh" set ui.networkMode "$SUBTARGET" 2>/dev/null || true; }
        "$QS_BIN" ipc -p "$SHELL_QML_PATH" call main handleCommand "$ACTION" "$TARGET" "$SUBTARGET" >/dev/null 2>&1
        exit 0
    fi

    if [[ "$TARGET" == "wallpaper" ]]; then
        handle_wallpaper_prep
        CURRENT_SRC=""
        # Authoritative source: state file written by set_wallpaper.sh on every
        # apply. Missing/empty file falls through to the process-query fallback.
        STATE_FILE="$HOME/.cache/current_wallpaper.txt"
        if [ -s "$STATE_FILE" ]; then
            read -r CURRENT_SRC < "$STATE_FILE" 2>/dev/null || CURRENT_SRC=""
        fi
        if [ -z "$CURRENT_SRC" ]; then
            if pgrep -a "mpvpaper" > /dev/null; then
                CURRENT_SRC=$(pgrep -a mpvpaper | grep -o "$SRC_DIR/[^' ]*" | head -n1)
            elif command -v awww >/dev/null; then
                CURRENT_SRC=$(awww query 2>/dev/null | grep -o "$SRC_DIR/[^ ]*" | head -n1)
            fi
        fi
        # Fallback to last applied wallpaper if wallpaper is disabled/killed
        if [ -z "$CURRENT_SRC" ]; then
            LAST_FILE="$HOME/.cache/last_wallpaper.txt"
            if [ -s "$LAST_FILE" ]; then
                read -r CURRENT_SRC < "$LAST_FILE" 2>/dev/null || CURRENT_SRC=""
            fi
        fi

        TARGET_THUMB=""
        if [ -n "$CURRENT_SRC" ]; then
            BASE=$(basename "$CURRENT_SRC")
            EXT="${BASE##*.}"
            [[ "${EXT,,}" =~ ^(mp4|mkv|mov|webm)$ ]] && TARGET_THUMB="000_$BASE" || TARGET_THUMB="$BASE"
        fi

        "$QS_BIN" ipc -p "$SHELL_QML_PATH" call main handleCommand "$ACTION" "$TARGET" "$TARGET_THUMB" >/dev/null 2>&1
    else
        "$QS_BIN" ipc -p "$SHELL_QML_PATH" call main handleCommand "$ACTION" "$TARGET" "$SUBTARGET" >/dev/null 2>&1
    fi
    exit 0
fi