#!/usr/bin/env bash

# 1. Define the exact paths QML uses
export QS_STATE_FOCUSTIME="$HOME/.local/state/quickshell/focustime"
export QS_RUN_FOCUSTIME="/run/user/$(id -u)/quickshell/focustime"

# 2. Ensure directories exist
mkdir -p "$QS_STATE_FOCUSTIME"
mkdir -p "$QS_RUN_FOCUSTIME"

# 3. Launch the daemon
exec python3 "$(dirname "$0")/focus_daemon.py"