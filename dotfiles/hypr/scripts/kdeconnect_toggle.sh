#!/usr/bin/env bash
# High-efficiency KDE Connect on-demand toggle
# Prevents continuous background network radio wakeups and saves ~80MB RAM.

set -euo pipefail

LOCK_FILE="/run/user/${UID}/kdeconnect_toggle.lock"
exec 200>"$LOCK_FILE"
flock -n 200 || exit 0

if pgrep -f '(^|/)kdeconnect-indicator( |$)' >/dev/null 2>&1 || pgrep -f '(^|/)kdeconnectd( |$)' >/dev/null 2>&1; then
    # Notify immediately first
    notify-send -a "KDE Connect" -u low -t 1500 "OFF"
    # Stop indicator, daemon, and UI cleanly (never kill hypr-kdeconnect-portal)
    pkill -f '(^|/)kdeconnect-indicator( |$)' 2>/dev/null || true
    pkill -f '(^|/)kdeconnectd( |$)' 2>/dev/null || true
    pkill -f '(^|/)kdeconnect-app( |$)' 2>/dev/null || true
    systemctl --user stop "dbus-*.org.kde.kdeconnect*.service" 2>/dev/null || true
    flock -u 200 || true
    exec 200>&- || true
else
    # Notify immediately first
    notify-send -a "KDE Connect" -u low -t 1500 "ON"
    # Close lock FD prior to spawning children so children do not inherit the lock!
    flock -u 200 || true
    exec 200>&- || true
    # Start indicator and daemon
    # kdeconnect-indicator provides the SNI tray icon and triggers D-Bus activation for kdeconnectd
    if command -v kdeconnect-indicator >/dev/null 2>&1; then
        nohup kdeconnect-indicator >/dev/null 2>&1 &
    elif command -v kdeconnectd >/dev/null 2>&1; then
        nohup kdeconnectd >/dev/null 2>&1 &
    fi
    # After daemon starts, check neighbour table for non-router link-local IPv6, refresh discovery
    (
        IFACE=$(ip route show default 2>/dev/null | awk '/^default/ {print $5}' | head -1)
        # Exclude router / gateway MACs
        LLADDR=$(ip -6 neigh show dev "${IFACE:-wlo1}" 2>/dev/null \
            | grep -v "router" \
            | awk '$5=="REACHABLE"||$5=="STALE"||$5=="DELAY"||$5=="PROBE" {if ($1~/^fe80::/) print $1}' \
            | head -1)
        if [ -n "$LLADDR" ]; then
            LLADDR_SCOPE="${LLADDR}%${IFACE:-wlo1}"
            CONFIG="$HOME/.config/kdeconnect/config"
            if [ -f "$CONFIG" ]; then
                if grep -q "^customDevices=" "$CONFIG"; then
                    sed -i "s|^customDevices=.*|customDevices=${LLADDR_SCOPE}|" "$CONFIG"
                else
                    echo "customDevices=${LLADDR_SCOPE}" >> "$CONFIG"
                fi
            fi
        fi
        kdeconnect-cli --refresh > /dev/null 2>&1 || true
    ) &
fi
