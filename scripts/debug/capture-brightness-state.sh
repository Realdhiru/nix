#!/usr/bin/env bash
# capture-brightness-state.sh — capture a reproducible State A/B snapshot for the
# ASUS brightness-keys-after-hibernate investigation.
#
# Usage:
#   sudo ./capture-brightness-state.sh A   # known-good: right after a working boot
#   sudo ./capture-brightness-state.sh B   # broken: after `systemctl suspend-then-hibernate`
#
# Run A and B with the EXACT same command order so outputs can be diffed.
# Outputs go to /tmp/brightness-ctrl/<STATE>/.
#
# Requires root (/proc/interrupts, /sys/bus/wmi, ACPI interrupts, journal).
# evtest/wev are optional; node discovery is done via sysfs either way.
#
set -u
STATE="${1:?usage: capture-brightness-state.sh <A|B>}"
STATE="$(printf '%s' "$STATE" | tr 'a-z' 'A-Z')"
case "$STATE" in A|B) ;; *) echo "STATE must be A or B"; exit 2 ;; esac

OUT="/tmp/brightness-ctrl/${STATE}"
mkdir -p "$OUT"
echo "Capturing State $STATE -> $OUT"

say() { printf '\n### %s\n' "$*" | tee -a "$OUT/00-manifest.txt"; }

# --- 1. Identity ---------------------------------------------------------------
say "1. Identity"
{
  uname -a
  printf 'cmdline: '; cat /proc/cmdline
  printf 'resume:  '; cat /sys/power/resume
  printf 'disk:    '; cat /sys/power/disk
  printf 'state:   '; cat /sys/power/state
  printf 'mem_sleep:'; cat /sys/power/mem_sleep
  date -u +'captured: %F %T UTC'
} > "$OUT/1-identity.txt" 2>&1

# --- 2. Modules -----------------------------------------------------------------
say "2. Modules (asus/wmi/video/input relevant)"
lsmod | grep -E '^(asus|asus_wmi|asus_nb_wmi|video|wmi|i8042|intel_vbtn|sparse_keymap|xe|i915)' > "$OUT/2-modules.txt"

# --- 3. Input devices -------------------------------------------------------------
say "3. /proc/bus/input/devices"
cat /proc/bus/input/devices > "$OUT/3-input.txt"

# --- 4. WMI device tree ------------------------------------------------------------
say "4. /sys/bus/wmi devices"
: > "$OUT/4-wmi.txt"
for d in /sys/bus/wmi/devices/*/; do
  echo "[$d]" >> "$OUT/4-wmi.txt"
  cat "$d/uevent" >> "$OUT/4-wmi.txt"
  if [ -L "$d/driver" ]; then echo "driver -> $(readlink "$d/driver")" >> "$OUT/4-wmi.txt"; fi
  cat "$d/notify_id" 2>/dev/null >> "$OUT/4-wmi.txt"
done

# --- 5. Module params ------------------------------------------------------------------
say "5. video + asus_wmi module params"
: > "$OUT/5-params.txt"
for f in /sys/module/video/parameters/* /sys/module/asus_wmi/parameters/*; do
  printf '%s=%s\n' "$f" "$(cat "$f" 2>/dev/null)" >> "$OUT/5-params.txt"
done

# --- 6. ACPI interrupt / GPE snapshot (pre) ----------------------------------------------
say "6. ACPI interrupts (pre-press)"
: > "$OUT/6-irq-pre.txt"
for f in /sys/firmware/acpi/interrupts/*; do
  printf '%s: %s\n' "$(basename "$f")" "$(cat "$f")" >> "$OUT/6-irq-pre.txt"
done
grep -E 'acpi|IR-.*acpi' /proc/interrupts >> "$OUT/6-irq-pre.txt" 2>/dev/null || true

# --- 7. Compositor device view ---------------------------------------------------------------
say "7. hyprctl devices"
hyprctl devices -j > "$OUT/7-hypr.txt" 2>&1 || true

# --- 8. Kernel log baseline ----------------------------------------------------------------
say "8. journalctl kernel filter (asus/wmi/acpi error/EC)"
journalctl -k -b 0 --no-pager --grep='asus_wmi|asus-nb-wmi|asus_nb_wmi|wmi|acpi.*error|EC:|intel_vbtn' > "$OUT/8-klog-baseline.txt"

# --- 9. systemd sleep-unit logs ---------------------------------------------------------------
say "9. suspend/hibernate unit logs"
{
  journalctl -b --no-pager -u systemd-suspend.service
  journalctl -b --no-pager -u systemd-hibernate.service
  journalctl -b --no-pager -u systemd-suspend-then-hibernate.service
} > "$OUT/9-sleep-units.txt"

# --- 10. Live key-press probe (30 s) -------------------------------------------------------------
say "10. LIVE: press brightness up x5, down x5, then Fn+F5 x5"
say "    when '>>> PRESS NOW <<<' appears"
mkdir -p "$OUT/live"
journalctl -k -f > "$OUT/live/10-klog-live.txt" &
JF_PID=$!
(
  python3 - <<'PYEOF'
import time, glob
t0 = time.time()
def cnts():
    r = {}
    for f in glob.glob('/sys/firmware/acpi/interrupts/*'):
        n = f.rsplit('/', 1)[1]
        if n in ('gpe6D','gpe6E','gpe_all','sci','sci_not'):
            try: r[n] = open(f).read().split()[0]
            except Exception: pass
    return r
def out(*a):
    print("t=%6.1f %s" % ((time.time()-t0), " ".join(a)), flush=True)
out("start")
dl = t0 + 31
while time.time() < dl:
    c = cnts()
    out(" ".join(f"{k}={v}" for k,v in c.items()))
    time.sleep(0.5)
out("end")
PYEOF
) > "$OUT/live/10-irq-stream.txt" &
IRQ_PID=$!
sleep 2
echo "   >>> PRESS NOW <<<  brightness up x5, down x5, then Fn+F5 x5"
sleep 29
kill "$JF_PID" 2>/dev/null || true
wait "$IRQ_PID" 2>/dev/null || true

# --- 11. Node discovery + optional evtest ------------------------------------------------
say "11. input node discovery (+ optional evtest)"
python3 - > "$OUT/11-nodes.txt" <<'PY'
import glob, os
want = ("Asus WMI hotkeys", "AT Translated Set 2 keyboard", "Video Bus")
for p in sorted(glob.glob('/sys/class/input/input*/')):
    try:
        name = open(p + 'name').read().strip()
    except Exception:
        continue
    if name in want:
        events = [os.path.basename(e) for e in glob.glob(p + 'event*')]
        print(f"{name}: {', '.join(e for e in events) or 'no event node'}")
PY

# --- 12. ACPI interrupt snapshot (post) ------------------------------------------------------
say "12. ACPI interrupts (post-press)"
: > "$OUT/12-irq-post.txt"
for f in /sys/firmware/acpi/interrupts/*; do
  printf '%s: %s\n' "$(basename "$f")" "$(cat "$f")" >> "$OUT/12-irq-post.txt"
done
grep -E 'acpi' /proc/interrupts >> "$OUT/12-irq-post.txt" 2>/dev/null || true

echo
echo "Capture complete for State $STATE:"; ls -la "$OUT"
echo
echo "Comparable files:"
echo "  1-identity 2-modules 3-input 4-wmi 5-params 6-irq-pre 7-hypr"
echo "  8-klog-baseline 9-sleep-units"
echo "  live/10-klog-live live/10-irq-stream 11-nodes 12-irq-post"
echo "Compare GPE/sci INCREMENTS (deltas), not absolute counter values."