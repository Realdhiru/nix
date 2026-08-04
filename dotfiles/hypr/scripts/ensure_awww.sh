#!/usr/bin/env bash
#
# ensure_awww.sh -- single source of truth for the awww-daemon lifecycle.
#
# Restart contract:
#   (none)     idempotent: ensure a healthy daemon is running; start only if
#              needed. Safe to call from anywhere, any number of times.
#   --restart  stop any running daemon, then start a fresh one. Used after
#              monitor-layout changes so layer surfaces re-initialize.
#   --stop     stop the daemon and clean up a stale socket. Used before a
#              video wallpaper takes over (mpvpaper).
#
# This is the ONLY place in the config that starts/stops/probes the daemon
# or touches its socket. All other scripts and QML panels delegate here.

set -euo pipefail

WAIT_INTERVAL=0.05                 # seconds between readiness/exited polls
WAIT_ITERATIONS=100                # 100 * WAIT_INTERVAL = wait-phase timeout
WAIT_TIMEOUT_SECS=5                # total wait phase timeout (~5s)

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

RESTART=0
STOP=0
case "${1:-}" in
  --restart) RESTART=1 ;;
  --stop)    STOP=1 ;;
esac

# The daemon is a Nix-wrapped binary: its process name (comm) is the
# truncated `.awww-daemon-wr`, NOT `awww-daemon`, so `-x` never matches.
# Match the daemon's command-line binary path instead. Anchoring on
# `bin/awww-daemon` also keeps pgrep/pkill from self-matching any shell
# whose command line merely mentions "awww-daemon".
DAEMON_MATCH="bin/awww-daemon"

is_running() { pgrep -f "$DAEMON_MATCH" >/dev/null 2>&1; }

# Wait for a SIGTERM'd daemon to actually exit.
wait_exited() {
  for _ in $(seq 1 "$WAIT_ITERATIONS"); do
    is_running || return 0
    sleep "$WAIT_INTERVAL"
  done
  return 1
}

stop_daemon() {
  is_running || return 0
  pkill -f "$DAEMON_MATCH" 2>/dev/null || true
  wait_exited && return 0
  echo "ensure_awww: daemon ignored SIGTERM; sending SIGKILL" >&2
  pkill -KILL -f "$DAEMON_MATCH" 2>/dev/null || true
  wait_exited || {
    echo "ensure_awww: daemon still running even after SIGKILL" >&2
    return 1
  }
}

# Recovery only: called after it is confirmed no daemon process exists.
remove_stale_socket() {
  rm -f "$RUNTIME_DIR"/wayland-*-awww-daemon.sock \
        "$RUNTIME_DIR"/awww-*.socket
}

if [ "$STOP" -eq 1 ]; then
  if ! stop_daemon; then
    echo "ensure_awww: --stop failed, daemon still running" >&2
    exit 1
  fi
  remove_stale_socket
  exit 0
fi

# Fast path: already healthy, do nothing.
if [ "$RESTART" -eq 0 ] && awww query >/dev/null 2>&1; then
  exit 0
fi

# Tear down any live instance before (re)starting.
if ! stop_daemon; then
  echo "ensure_awww: could not stop existing daemon; aborting start" >&2
  exit 1
fi

# No daemon process exists, so a leftover socket is stale -- safe to clear.
remove_stale_socket

# Always start with the pixel format the 10-bit panel expects.
awww-daemon --format xrgb >/dev/null 2>&1 &

# Block until the daemon answers a query.
for _ in $(seq 1 "$WAIT_ITERATIONS"); do
  awww query >/dev/null 2>&1 && exit 0
  sleep "$WAIT_INTERVAL"
done

echo "ensure_awww: daemon started but never answered 'awww query' within $WAIT_TIMEOUT_SECS seconds" >&2
echo "ensure_awww: check 'awww query' and 'journalctl --user -b' for daemon errors" >&2
exit 1
