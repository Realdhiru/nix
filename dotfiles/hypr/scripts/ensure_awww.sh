#!/usr/bin/env bash
#
# ensure_awww.sh -- single source of truth for the awww-daemon lifecycle.
#
# Restart contract:
#   (none)     idempotent: ensure a healthy daemon is running; start only if
#              needed. Safe to call from anywhere, any number of times.
#   --restart  stop any running daemon, then start a fresh one, re-applying
#              the previously displayed wallpapers. Used after monitor-layout
#              changes so layer surfaces re-initialize.
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

# The daemon is a Nix-wrapped binary. Its `comm` is truncated to
# `.awww-daemon-wr` (not `awww-daemon`), so `pgrep -x` never matches, and
# `pgrep -f` self-matches any shell whose command line merely mentions
# "awww-daemon". Instead, match the immutable Nix wrapper suffix of the
# process's resolved executable so we only ever act on the real daemon.
daemon_pids() {
  local pid exe
  for pid in /proc/[0-9]*; do
    [ -r "$pid/exe" ] || continue
    exe=$(readlink "$pid/exe" 2>/dev/null) || continue
    case "$exe" in
      */bin/.awww-daemon-wrapped) printf '%s\n' "${pid#/proc/}" ;;
    esac
  done
}

is_running() { [ -n "$(daemon_pids)" ]; }

# Wait for a SIGTERM'd daemon to actually exit.
wait_exited() {
  for _ in $(seq 1 "$WAIT_ITERATIONS"); do
    is_running || return 0
    sleep "$WAIT_INTERVAL"
  done
  return 1
}

stop_daemon() {
  local pids pid
  pids=$(daemon_pids)
  [ -z "$pids" ] && return 0
  for pid in $pids; do
    kill "$pid" 2>/dev/null || true
  done
  wait_exited && return 0
  echo "ensure_awww: daemon ignored SIGTERM; sending SIGKILL" >&2
  for pid in $(daemon_pids); do
    kill -KILL "$pid" 2>/dev/null || true
  done
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

# The daemon's IPC socket exists for the daemon's entire lifetime and vanishes
# when it exits, so `awww query` can never succeed without it. Checking the
# socket first lets us skip the guaranteed-to-timeout query (~0.5 s client-side
# connect timeout) when the daemon is known to be absent, e.g. the first
# image->static switch after a video wallpaper has stopped the daemon.
daemon_socket_exists() {
  compgen -G "$RUNTIME_DIR/wayland-*-awww-daemon.sock" >/dev/null 2>&1
}

# Prune awww's derived animation-frame cache on every daemon (re)start.
#
# `awww img` without `--outputs` calls update_disconnected_caches(), which
# opens the cache dir and fs::read()s EVERY file that doesn't match a known
# connected output -- i.e. all the `*_crop_Argb` animation-frame cache files
# -- as if they were small state files (common/src/ipc/mod.rs). With years of
# stale gif caches this became ~1.8 GB of disk reads per wallpaper push
# (measured: one 300 MB stale file turned a single push into 22 s; an empty
# cache made it 0.29 s).
#
# These files are pure derived data (pre-resized RGB frames) and are
# regenerated on demand the next time the gif is set, so deleting them is
# safe. We match ONLY the `*_crop_Argb` suffix and only at the versioned
# cache depth: state files (e.g. `eDP-1`) and everything else are untouched.
prune_frame_cache() {
  local cache_root
  cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/awww"
  [ -d "$cache_root" ] || return 0
  find "$cache_root" -mindepth 2 -maxdepth 2 -type f -name '*_crop_Argb*' \
    -delete 2>/dev/null || true
}

# Snapshot `monitor|path` pairs for every output currently showing an image.
# `awww query` prints `: <mon>: <w>x<h>, scale: <s>, currently displaying: image: <path>`.
capture_wallpapers() {
  awww query 2>/dev/null \
    | sed -n 's/^: \([^:]*\): .*currently displaying: image: \(.*\)/\1|\2/p' \
    || true
}

restore_wallpapers() {
  local mon path
  while IFS='|' read -r mon path; do
    [ -n "$mon" ] && [ -n "$path" ] || continue
    [ -f "$path" ] || continue
    awww img --transition-type fade --transition-step 255 \
      --transition-duration 0.1 --transition-fps 60 \
      --outputs "$mon" "$path" >/dev/null 2>&1 || true
  done <<< "$WALLPAPERS"
}

if [ "$STOP" -eq 1 ]; then
  if ! stop_daemon; then
    echo "ensure_awww: --stop failed, daemon still running" >&2
    exit 1
  fi
  remove_stale_socket
  exit 0
fi

# Snapshot the current wallpapers while the daemon is still healthy so they
# can be re-applied after the restart. Only meaningful for --restart.
WALLPAPERS=""
if [ "$RESTART" -eq 1 ]; then
  WALLPAPERS="$(capture_wallpapers)"
fi

# Fast path: already healthy, do nothing. The socket check avoids the ~0.5 s
# query timeout on the daemon-down path (S3); when the socket exists the query
# still decides liveness, so behavior is unchanged.
if [ "$RESTART" -eq 0 ] && daemon_socket_exists && awww query >/dev/null 2>&1; then
  exit 0
fi

# Tear down any live instance before (re)starting.
if ! stop_daemon; then
  echo "ensure_awww: could not stop existing daemon; aborting start" >&2
  exit 1
fi

# No daemon process exists, so a leftover socket is stale -- safe to clear.
remove_stale_socket

# S1: drop derived animation-frame caches before a fresh daemon starts so the
# next `awww img` does not re-read gigabytes of stale gif frames.
prune_frame_cache

# Always start with the pixel format the 10-bit panel expects. `--no-cache`
# disables awww's built-in "restore last wallpaper per output" on startup,
# which otherwise flashes the stale pre-video wallpaper before the newly
# selected one is pushed (daemon/src/wallpaper.rs commit_surface_changes).
# Our own restore path (--restart) and set_wallpaper.sh cover restoring.
awww-daemon --no-cache --format xrgb >/dev/null 2>&1 &

# Block until the daemon answers a query, then re-apply any captured wallpapers.
for _ in $(seq 1 "$WAIT_ITERATIONS"); do
  if awww query >/dev/null 2>&1; then
    if [ "$RESTART" -eq 1 ] && [ -n "$WALLPAPERS" ]; then
      restore_wallpapers
    fi
    exit 0
  fi
  sleep "$WAIT_INTERVAL"
done

echo "ensure_awww: daemon started but never answered 'awww query' within $WAIT_TIMEOUT_SECS seconds" >&2
echo "ensure_awww: check 'awww query' and 'journalctl --user -b' for daemon errors" >&2
exit 1
