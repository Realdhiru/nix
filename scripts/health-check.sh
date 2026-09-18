#!/usr/bin/env bash
# Post-switch health gate for rebuild() — see ~/nix/docs/flow.md §12.
#
# Usage: health-check.sh <ISO-8601 start timestamp>
#   The timestamp scopes all journal scans: only events AFTER the switch
#   are considered, so historical GPU errors can never fail this gate.
#
# Exit codes:
#   0  healthy          (critical checks green; warnings printed if any)
#   1  CRITICAL FAIL    (rebuild() must auto-rollback)
#   2  warnings only    (never triggers rollback)
#
# Rules (earned 2026-08-16, i915 hang incident):
#   - NEVER kill, touch, or disrupt pre-existing wezterm processes or windows.
#   - The wezterm probe is an isolated --always-new-process instance with a
#     self-closing command; only THIS probe's own pid may ever be killed.
#   - GPU-HANG detection is scoped to [start, now] AND to the probe pid.
set -u

START="${1:?usage: health-check.sh <ISO-8601 timestamp>}"

LOG="$HOME/.cache/nix_health_$(date +%Y%m%d-%H%M%S).log"
: > "$LOG"
exec >> "$LOG" 2>&1
echo "health-check: started $(date -Is), window since $START"
echo "health-check: log = $LOG"

critical=0
warnings=0

pass()  { printf '%-10s %s\n' "OK" "$1"; }
warn()  { printf '%-10s %s\n' "WARN" "$1"; warnings=1; }
fail()  { printf '%-10s %s\n' "CRITICAL" "$1"; critical=1; }

# ---------------------------------------------------------------- Hyprland
if hyprctl activewindow >/dev/null 2>&1 || pgrep -x Hyprland >/dev/null; then
  pass "Hyprland alive"
else
  fail "Hyprland dead (hyprctl + pgrep both failed) — session gone"
fi

# ------------------------------------------------- isolated wezterm probe
# Launch a dedicated instance whose command self-exits after 6s; the window
# closes itself. Existing windows/processes are never touched.
timeout 20 wezterm start --always-new-process -- /bin/sh -c 'sleep 6' \
  >/dev/null 2>&1 &
wcli_pid=$!

# Find the probe's wezterm-gui pid(s) — single pgrep ancestor walk instead
# of repeated BFS over full ps table.
probe_pids=""
for _ in $(seq 1 20); do
  # Direct children of cli pid, then their children (grandchildren)
  children=$(pgrep -P "$wcli_pid" 2>/dev/null | tr '\n' ' ')
  grandchildren=""
  for c in $children; do
    grandchildren="$grandchildren $(pgrep -P "$c" 2>/dev/null | tr '\n' ' ')"
  done
  all="$children $grandchildren"
  gui_pids=""
  for p in $all; do
    [ -z "$p" ] && continue
    comm=$(cat "/proc/$p/comm" 2>/dev/null || true)
    [ "$comm" = "wezterm-gui" ] && gui_pids="$gui_pids $p"
  done
  probe_pids=$(echo "$gui_pids" | tr ' ' '\n' | sort -un | tr '\n' ' ')
  [ -n "$(echo "$probe_pids" | tr -d ' ')" ] && break
  sleep 0.25
done
wpid=$(echo "$probe_pids" | awk '{print $1}')

wait "$wcli_pid"
rc=$?

probe_hangs=0
if [ -n "$(echo "$probe_pids" | tr -d ' ')" ]; then
  for p in $probe_pids; do
    [ -z "$p" ] && continue
    n=$(journalctl -k --since "$START" --no-pager 2>/dev/null \
      | grep -c "wezterm-gui\[$p\]" || true)
    probe_hangs=$((probe_hangs + n))
  done
fi

echo "probe: cli_rc=$rc pids=[${probe_pids:-none}] probe_attributed_gpu_hangs=$probe_hangs"

[ "$rc" -eq 0 ] || fail "wezterm probe failed (rc=$rc) — terminal did not launch/close cleanly"
[ -n "$wpid" ] || fail "wezterm probe never spawned a gui process"
[ "$probe_hangs" -eq 0 ] || fail "i915 GPU HANG attributed to probe wezterm (see below)"

# Only ever kill THIS probe's own pids if it leaked past the 20s backstop.
for p in $probe_pids; do
  [ -z "$p" ] && continue
  kill "$p" >/dev/null 2>&1 || true
done

# ------------------------------------------- global GPU hang delta (warning)
other_hangs=$(journalctl -k --since "$START" --no-pager 2>/dev/null \
  | grep -c "GPU HANG" || true)
other_hangs=$((other_hangs - probe_hangs))
[ "$other_hangs" -le 0 ] || warn "post-switch GPU HANGs from other processes: $other_hangs"

# ------------------------------------------------- user services (batched)
svc_bad=""
for u in quickshell pipewire pipewire-pulse wireplumber xdg-desktop-portal; do
  systemctl --user is-active "$u" >/dev/null 2>&1 || svc_bad="$svc_bad $u"
done
if [ -z "$svc_bad" ]; then
  pass "all user services active (quickshell, pipewire stack, portal)"
else
  # quickshell/portal are warnings; pipewire units are also warnings (non-blocking)
  warn "inactive user units:$svc_bad"
fi

# ------------------------------------------------------------ verdict
if [ "$critical" -eq 1 ]; then
  echo "health-check: exit CRITICAL"
  exit 1
elif [ "$warnings" -eq 1 ]; then
  echo "health-check: exit WARNINGS"
  exit 2
else
  echo "health-check: exit OK"
  exit 0
fi