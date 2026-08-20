#!/usr/bin/env bash

# Strict execution environment
set -uo pipefail

# Source and initialize quickshell dynamic caching
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "lock"

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

while true; do
    "$QS_BIN" -p "$HOME/.config/hypr/scripts/quickshell/Lock.qml"
    EXIT_CODE=$?
    
    # If the lock exits cleanly (user unlocked successfully), break the loop
    if [ $EXIT_CODE -eq 0 ]; then
        break
    fi
    
    # If it crashed, wait 1 second to avoid spin-locking, then restart
    sleep 1
done