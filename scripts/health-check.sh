#!/usr/bin/env bash
# Post-switch health gate for rebuild() — see ~/nix/docs/flow.md §6.
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
#   - NEVER kill, touch, or disrupt pre-existing terminals.
#   - The alacritty probe runs ISOLATED in a private XDG_RUNTIME_DIR;
#     only THIS probe's own pid may ever be killed.
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
if timeout 3 hyprctl activewindow >/dev/null 2>&1 || pgrep -x Hyprland >/dev/null; then
  pass "Hyprland alive"
else
  fail "Hyprland dead (hyprctl + pgrep both failed) — session gone"
fi

# --------------------------------------------------- failed units (both scopes)
system_failed=$(systemctl --failed --no-legend --plain --no-pager 2>/dev/null || true)
user_failed=$(systemctl --user --failed --no-legend --plain --no-pager 2>/dev/null || true)
if [ -n "$system_failed$user_failed" ]; then
  printf 'system failed units:\n%s\nuser failed units:\n%s\n' "$system_failed" "$user_failed"
  fail "failed system or user units are present"
else
  pass "no failed system or user units"
fi

# ---------------------------------------------- stuck D-state / I/O pressure
d_state_pids() {
  ps -eo pid=,ppid=,stat= | awk '$2 != 2 && $1 != 2 && $3 ~ /^D/ {print $1}' | sort -n
}
d_first=$(d_state_pids)
sleep 2
d_second=$(d_state_pids)
if [ -n "$d_second" ] && [ "$d_first" = "$d_second" ]; then
  fail "processes remained in D state across a 2-second observation: $d_second"
else
  pass "no persistent D-state process across 2 seconds"
fi
if [ -r /proc/pressure/io ]; then
  io_full=$(awk '/^full / {for(i=1;i<=NF;i++) if($i ~ /^avg10=/){split($i,a,"="); print a[2]}}' /proc/pressure/io)
  io_full=${io_full:-0}
  if awk -v value="$io_full" 'BEGIN{exit !(value >= 10)}'; then
    fail "full I/O pressure avg10 is ${io_full}% (threshold 10%)"
  else
    pass "full I/O pressure avg10 is ${io_full}%"
  fi
else
  warn "I/O pressure is unavailable from /proc/pressure/io"
fi

# ----------------------------------------------- active panel refresh policy
ac_online=0
for online_file in /sys/class/power_supply/*/online; do
  [ -r "$online_file" ] || continue
  [ "$(cat "$online_file" 2>/dev/null || echo 0)" = 1 ] && ac_online=1
done
if [ "$ac_online" -eq 1 ]; then cap=${HYPR_REFRESH_AC:-120}; else cap=${HYPR_REFRESH_BATTERY:-60}; fi
monitor_json=$(timeout 3 hyprctl monitors -j 2>/dev/null || true)
refresh_pair=$(jq -r --argjson cap "$cap" '
  ([.[] | select((.name | test("^(eDP|LVDS|DSI|MIPI)")))][0] // .[0])
  | if . == null then empty else
      ([.availableModes[]? | capture("@(?<rate>[0-9.]+)Hz$").rate | tonumber] as $rates
       | ([ $rates[] | select(. <= $cap) ] | if length > 0 then max else ($rates|min) end)) as $target
      | "\(.refreshRate) \($target)"
    end
' <<< "$monitor_json" 2>/dev/null || true)
if [ -n "$refresh_pair" ]; then
  read -r actual_refresh expected_refresh <<< "$refresh_pair"
  if awk -v actual="$actual_refresh" -v expected="$expected_refresh" 'BEGIN{d=actual-expected;if(d<0)d=-d;exit !(d<=1)}'; then
    pass "panel refresh ${actual_refresh}Hz matches ${expected_refresh}Hz policy (cap ${cap}Hz)"
  else
    fail "panel refresh ${actual_refresh}Hz differs from expected ${expected_refresh}Hz (cap ${cap}Hz)"
  fi
else
  fail "cannot read active internal panel refresh policy"
fi

# ---------------------------------------------------- isolated alacritty probe
# Default terminal is alacritty (keybind: alacritty).
# Launch a dedicated standalone instance whose command self-exits after 1.5s; the
# window closes itself. Existing windows/processes are never touched.
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
probe_runtime=$(mktemp -d) || probe_runtime="$HOME/.cache/alacrittyprobe-$$"
mkdir -p "$probe_runtime"
if [ -e "$runtime/wayland-1" ]; then
  ln -s "$runtime/wayland-1" "$probe_runtime/wayland-1"
  [ -e "$runtime/wayland-1.lock" ] \
    && ln -s "$runtime/wayland-1.lock" "$probe_runtime/wayland-1.lock"
fi

XDG_RUNTIME_DIR="$probe_runtime" timeout 10 alacritty -e sh -c 'sleep 1.5' \
  >/dev/null 2>&1 &
wcli_pid=$!

# Find the probe's alacritty pid(s) — single pgrep ancestor walk instead
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
    [ "$comm" = "alacritty" ] && gui_pids="$gui_pids $p"
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
      | grep -c "alacritty\[$p\]" || true)
    probe_hangs=$((probe_hangs + n))
  done
fi

echo "probe: cli_rc=$rc pids=[${probe_pids:-none}] probe_attributed_gpu_hangs=$probe_hangs"

[ "$rc" -eq 0 ] || fail "alacritty probe failed (rc=$rc) — terminal did not launch/close cleanly"
[ -n "$wpid" ] || fail "alacritty probe never spawned a gui process"
[ "$probe_hangs" -eq 0 ] || fail "i915 GPU HANG attributed to probe alacritty (see below)"

# Only ever kill THIS probe's own pids if it leaked past the 20s backstop.
for p in $probe_pids; do
  [ -z "$p" ] && continue
  kill "$p" >/dev/null 2>&1 || true
done
rm -rf "$probe_runtime"

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
