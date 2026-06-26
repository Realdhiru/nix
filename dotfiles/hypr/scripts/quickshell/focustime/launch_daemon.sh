#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"

pkill -f focus_daemon.py

while true; do
    python3 "$(dirname "$0")/focus_daemon.py"
    sleep 2
done