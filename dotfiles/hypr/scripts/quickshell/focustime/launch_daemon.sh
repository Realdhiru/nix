#!/usr/bin/env bash
# Variables are bypassed. The Python daemon natively handles its own absolute paths.
exec python3 "$(dirname "$0")/focus_daemon.py"