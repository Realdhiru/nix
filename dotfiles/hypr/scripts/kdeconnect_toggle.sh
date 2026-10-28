#!/usr/bin/env bash
# High-efficiency KDE Connect on-demand toggle
# Prevents continuous background network radio wakeups and saves ~80MB RAM.

set -euo pipefail

LOCK_FILE="/run/user/${UID}/kdeconnect_toggle.lock"
exec 200>"$LOCK_FILE"
flock -n 200 || exit 0

if pgrep -f "kdeconnect-indicator" >/dev/null 2>&1 || pgrep -f "kdeconnectd" >/dev/null 2>&1; then
    # Notify immediately first
    notify-send -a "KDE Connect" -u low -t 1500 "OFF"
    # Stop indicator, daemon, and UI cleanly
    pkill -f "kdeconnect-indicator" 2>/dev/null || true
    pkill -f "kdeconnectd" 2>/dev/null || true
    pkill -f "kdeconnect-app" 2>/dev/null || true
    systemctl --user stop "dbus-*.org.kde.kdeconnect*.service" 2>/dev/null || true
else
    # Notify immediately first
    notify-send -a "KDE Connect" -u low -t 1500 "ON"
    # Currently stopped -> Start indicator and daemon
    # kdeconnect-indicator provides the SNI tray icon and triggers D-Bus activation for kdeconnectd
    if command -v kdeconnect-indicator >/dev/null 2>&1; then
        kdeconnect-indicator >/dev/null 2>&1 & disown
    elif command -v kdeconnectd >/dev/null 2>&1; then
        kdeconnectd >/dev/null 2>&1 & disown
    fi
fi
