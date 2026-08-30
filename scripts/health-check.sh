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
# Launch a dedicated instance whose command self-exits after 8s; the window
# closes itself. Existing windows/processes are never touched.
wcli_pid=
timeout 25 wezterm start --always-new-process -- /bin/sh -c 'sleep 8' \
  >/dev/null 2>&1 &
wcli_pid=$!

# Capture the probe's exact gui pid TREE: `wezterm start` spawns a
# launcher/daemon `wezterm-gui` (direct child of the CLI) which then spawns
# the per-window `wezterm-gui` (grandchild) — the window process is the one
# i915 attributes hangs to. Track every descendant so attribution is exact.
wpid=
probe_pids=""
for _ in $(seq 1 40); do
  # BFS over ps snapshot: all descendants of $wcli_pid, then filter for wezterm-gui
  ps_out=$(ps -eo pid=,ppid=,comm=)
  frontier="$wcli_pid"
  all_descendants=""
  for _ in $(seq 1 6); do
    [ -z "$frontier" ] && break
    next_frontier=$(echo "$ps_out" | awk -v f="$frontier" '
      BEGIN { split(f, arr, " "); for (i in arr) pids[arr[i]] = 1 }
      pids[$2] { print $1 }
    ' | tr '\n' ' ')
    if [ -n "$next_frontier" ]; then
      all_descendants="$all_descendants $next_frontier"
      frontier="$next_frontier"
    else
      break
    fi
  done
  gui_pids=$(echo "$ps_out" | awk -v d="$all_descendants" '
    BEGIN { split(d, arr, " "); for (i in arr) pids[arr[i]] = 1 }
    pids[$1] && $3 == "wezterm-gui" { print $1 }
  ' | tr '\n' ' ')
  probe_pids=$(echo "$gui_pids" | tr ' ' '\n' | sort -un | tr '\n' ' ')
  [ -n "$probe_pids" ] && break
  sleep 0.5
done
wpid=$(echo "$probe_pids" | awk '{print $1}')

wait "$wcli_pid"
rc=$?

probe_hangs=0
if [ -n "$probe_pids" ]; then
  probe_hangs=0
  for p in $probe_pids; do
    n=$(journalctl -k --since "$START" --no-pager 2>/dev/null \
      | grep -c "wezterm-gui\[$p\]" || true)
    probe_hangs=$((probe_hangs + n))
  done
fi

echo "probe: cli_rc=$rc pids=[${probe_pids:-none}] probe_attributed_gpu_hangs=$probe_hangs"

if [ "$rc" -ne 0 ]; then
  fail "wezterm probe failed (rc=$rc) — terminal did not launch/close cleanly"
fi
[ -n "$wpid" ] || fail "wezterm probe never spawned a gui process"
[ "$probe_hangs" -eq 0 ] || fail "i915 GPU HANG attributed to probe wezterm (see below)"

# Only ever kill THIS probe's own pids if it leaked past the 25s backstop.
for p in $probe_pids; do
  kill "$p" >/dev/null 2>&1 || true
done

# ------------------------------------------- global GPU hang delta (warning)
other_hangs=$(journalctl -k --since "$START" --no-pager 2>/dev/null \
  | grep -c "GPU HANG" || true)
other_hangs=$((other_hangs - probe_hangs))
[ "$other_hangs" -le 0 ] || warn "post-switch GPU HANGs from other processes: $other_hangs"

# ---------------------------------------------------------------- quickshell
if pgrep -f "quickshell" >/dev/null; then
  pass "quickshell alive"
else
  warn "quickshell not running"
fi

# ---------------------------------------------------------------- pipewire
pw_bad=""
for u in pipewire pipewire-pulse wireplumber; do
  systemctl --user is-active "$u" >/dev/null 2>&1 || pw_bad="$pw_bad $u"
done
if [ -z "$pw_bad" ]; then
  pass "pipewire / pipewire-pulse / wireplumber active"
else
  warn "inactive user units:$pw_bad"
fi

# ------------------------------------------------------------ portals (warn)
if systemctl --user is-active xdg-desktop-portal >/dev/null 2>&1; then
  pass "xdg-desktop-portal active"
else
  warn "xdg-desktop-portal inactive (known broken 2026-08-16 — non-blocking)"
fi

echo "health-check: exit $([ "$critical" -eq 1 ] && echo CRITICAL || ( [ "$warnings" -eq 1 ] && echo WARNINGS || echo OK ))"
exit "$([ "$critical" -eq 1 ] && echo 1 || ( [ "$warnings" -eq 1 ] && echo 2 || echo 0))"