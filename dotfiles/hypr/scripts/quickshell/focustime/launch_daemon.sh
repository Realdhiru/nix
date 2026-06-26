#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "focustime"
exec python3 "$(dirname "$0")/focus_daemon.py"