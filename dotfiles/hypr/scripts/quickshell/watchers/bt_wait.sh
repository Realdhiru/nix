#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

PIPE="$QS_RUN_DIR/qs_bt_wait_$$.fifo"
mkfifo "$PIPE" 2>/dev/null

# Clean target ensuring the entire subshell group is eliminated
trap 'rm -f "$PIPE"; pkill -P $$ 2>/dev/null; exit 0' EXIT INT TERM

LC_ALL=C dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'" 2>/dev/null | grep --line-buffered 'string "Connected"' > "$PIPE" &
LC_ALL=C dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Adapter1'" 2>/dev/null | grep --line-buffered 'string "Powered"' > "$PIPE" &

# Failsafe timeout matching audio_wait.sh/battery_wait.sh/network_wait.sh —
# without this, a quiet Bluetooth state (no connect/power events for a
# while) left this read blocked forever, and since bash defers its own
# EXIT trap until the current foreground command returns, an external
# SIGTERM from Quickshell tearing the process down couldn't interrupt it
# either — same leak mechanism confirmed in network_wait.sh via pgrep.
timeout 10 bash -c 'read -r _ < "$1"' _ "$PIPE"

# Hard limit on execution frequency if dbus spams connection signals
sleep 1.5