#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "focustime"

# FIXED: Explicitly export variables so the Python subshell receives them
export QS_STATE_FOCUSTIME="$QS_STATE_FOCUSTIME"
export QS_RUN_FOCUSTIME="$QS_RUN_FOCUSTIME"

exec python3 "$(dirname "$0")/focus_daemon.py"