#!/usr/bin/env bash

CACHE_FILE="/tmp/qs_sys_fetcher_cache.txt"

# 1. Read instantaneous current values
read -r _ u n s i io ir so st g gn <<< "$(grep '^cpu ' /proc/stat)"

# Sum rx/tx from the interface actually carrying the default route, not a
# name-prefix guess. The old heuristic (any interface starting with 'e' or
# 'w') would also match VPN tunnels (wg0), Docker/podman veth pairs, or a
# second idle wifi/ethernet interface — any of those being active at the
# same time silently pollutes or double-counts the total, which is exactly
# what "not reliably showing" looks like from the UI (erratic, sometimes
# right, sometimes not). Falls back to the old heuristic only if there's
# genuinely no default route (e.g. fully offline) so the widget doesn't
# just go blank in that case.
DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
if [ -n "$DEFAULT_IFACE" ]; then
    read rx tx <<< "$(awk -v iface="${DEFAULT_IFACE}:" '$1==iface{print $2, $10}' /proc/net/dev)"
else
    read rx tx <<< "$(awk -v IGNORECASE=1 '/^ *[ew]/{rx+=$2; tx+=$10} END{print rx, tx}' /proc/net/dev)"
fi
rx=${rx:-0}; tx=${tx:-0}

NOW=$(date +%s%N 2>/dev/null || date +%s000000000)

# 2. Extract previous values from cache
if [ -f "$CACHE_FILE" ]; then
    read -r p_u p_n p_s p_i p_io p_ir p_so p_st p_rx p_tx p_now < "$CACHE_FILE"
    # Guard against a corrupted/partial cache line (e.g. this script got
    # killed mid-write on a prior run) leaving fewer fields than expected —
    # an empty p_now would make the arithmetic test below error out and
    # fall through with garbage values instead of cleanly treating this as
    # a fresh first sample.
    if ! [[ "$p_now" =~ ^[0-9]+$ ]]; then
        p_u=0; p_n=0; p_s=0; p_i=0; p_io=0; p_ir=0; p_so=0; p_st=0; p_rx=0; p_tx=0; p_now=0
    fi
else
    p_u=0; p_n=0; p_s=0; p_i=0; p_io=0; p_ir=0; p_so=0; p_st=0; p_rx=0; p_tx=0; p_now=0
fi

# 3. Write new state instantly
echo "$u $n $s $i $io $ir $so $st $rx $tx $NOW" > "$CACHE_FILE"

# 4. Calculate Deltas
if [ "$p_now" -eq 0 ]; then
    CPU_USAGE=0
    RX_RATE=0
    TX_RATE=0
else
    IDLE1=$p_i; TOTAL1=$((p_u + p_n + p_s + p_i + p_io + p_ir + p_so + p_st))
    IDLE2=$i;   TOTAL2=$((u + n + s + i + io + ir + so + st))
    DIFF_IDLE=$((IDLE2 - IDLE1))
    DIFF_TOTAL=$((TOTAL2 - TOTAL1))

    if [ "$DIFF_TOTAL" -eq 0 ]; then CPU_USAGE=0; else CPU_USAGE=$(( 100 * (DIFF_TOTAL - DIFF_IDLE) / DIFF_TOTAL )); fi

    # Enforce strict positive limits to block negative UI byte spikes on network reset
    TIME_DIFF_SEC=$(awk "BEGIN {print ($NOW - $p_now) / 1000000000}")
    # Parens around the comparison are required here — inside a printf
    # argument list, a bare `>` is parsed by awk as output redirection
    # (like `print x > "file"`), not a numeric comparison. Without the
    # parens this was a syntax error on every single invocation, silently
    # leaving RX_RATE/TX_RATE empty (confirmed: this is why net speed
    # never showed real values, not the interface-selection logic above).
    if awk "BEGIN {exit !($TIME_DIFF_SEC > 0)}"; then
        RX_RATE=$(awk "BEGIN {val=($rx - $p_rx) / $TIME_DIFF_SEC; printf \"%d\", (val>0?val:0)}")
        TX_RATE=$(awk "BEGIN {val=($tx - $p_tx) / $TIME_DIFF_SEC; printf \"%d\", (val>0?val:0)}")
    else
        RX_RATE=0; TX_RATE=0
    fi
fi

# --- RAM Calculation (Snapshot) ---
while IFS=":" read -r key val; do
    case "$key" in
        MemTotal) TOTAL_MEM=$(echo "$val" | awk '{print $1}') ;;
        MemAvailable) AVAIL_MEM=$(echo "$val" | awk '{print $1}') ;;
    esac
done < /proc/meminfo
USED_MEM=$((TOTAL_MEM - AVAIL_MEM))
RAM_PCT=$(( 100 * USED_MEM / TOTAL_MEM ))
RAM_GB=$(awk "BEGIN {printf \"%.1f\", $USED_MEM / 1024 / 1024}")

# --- Temperature Calculation (Snapshot) ---
TEMP_RAW=""
for hwmon in /sys/class/hwmon/hwmon*; do
    if [ -f "$hwmon/name" ]; then
        hwmon_name=$(cat "$hwmon/name" 2>/dev/null)
        if [[ "$hwmon_name" =~ ^(coretemp|k10temp|zenpower|cpu_thermal|bcm2835_thermal)$ ]]; then
            if [ -f "$hwmon/temp1_input" ]; then
                TEMP_RAW=$(cat "$hwmon/temp1_input" 2>/dev/null)
                break
            fi
        fi
    fi
done

if [ -z "$TEMP_RAW" ]; then
    for tz in /sys/class/thermal/thermal_zone*; do
        if [ -f "$tz/type" ]; then
            tz_type=$(cat "$tz/type" 2>/dev/null)
            if [[ "$tz_type" =~ ^(x86_pkg_temp|cpu_thermal|cpu-thermal)$ ]]; then
                TEMP_RAW=$(cat "$tz/temp" 2>/dev/null)
                break
            fi
        fi
    done
fi

if [ -z "$TEMP_RAW" ]; then
    TEMP_RAW=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
fi

if [ "$TEMP_RAW" -gt 1000 ]; then TEMP=$((TEMP_RAW / 1000)); else TEMP=$TEMP_RAW; fi

# --- Output formatted string ---
echo "$CPU_USAGE|$RAM_PCT|$RAM_GB|$TEMP|$RX_RATE|$TX_RATE"