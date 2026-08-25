#!/usr/bin/env bash
# Event-driven watcher reading actual hardware sysfs nodes and display refresh rate.
# Emits real-time newline-delimited JSON events to Quickshell SplitParser.
# STRICT RULE: No fake or fallback defaults. If state is unreadable, emits "unknown".
set -euo pipefail

read_state() {
    # 1. Platform Profile
    prof=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "unknown")
    
    # 2. EPP across ALL 16 cpufreq policy domains
    first_epp=""
    epp_mismatch="0"
    for p in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
        if [ -e "$p" ]; then
            val=$(cat "$p" 2>/dev/null || echo "")
            if [ -z "$first_epp" ]; then
                first_epp="$val"
            elif [ "$val" != "$first_epp" ]; then
                epp_mismatch="1"
                break
            fi
        fi
    done

    if [ "$epp_mismatch" = "1" ]; then
        epp="mismatch"
    else
        epp="${first_epp:-unknown}"
    fi

    # 3. CPU Turbo Boost State
    no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "")
    if [ "$no_turbo" = "0" ]; then
        boost="enabled"
    elif [ "$no_turbo" = "1" ]; then
        boost="disabled"
    else
        boost="unknown"
    fi

    # 4. Intel HWP Dynamic Boost State
    hwp_dyn=$(cat /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost 2>/dev/null || echo "")
    if [ "$hwp_dyn" = "1" ]; then
        hwp_dyn_boost="enabled"
    elif [ "$hwp_dyn" = "0" ]; then
        hwp_dyn_boost="disabled"
    else
        hwp_dyn_boost="unknown"
    fi
    
    # 5. AC Online Status
    ac_state="unknown"
    for p in /sys/class/power_supply/AC* /sys/class/power_supply/ADP* /sys/class/power_supply/ucsi-source-psy-USBC000:001; do
        if [ -e "$p/online" ]; then
            val=$(cat "$p/online" 2>/dev/null || echo "")
            if [ "$val" = "1" ] || [ "$val" = "0" ]; then
                ac_state="$val"
                break
            fi
        fi
    done

    # 6. Current Display Refresh Rate (Raw read, zero fake default)
    rr_raw=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].refreshRate' 2>/dev/null || echo "")
    if [ -n "$rr_raw" ] && [ "$rr_raw" != "null" ]; then
        rr=$(echo "$rr_raw" | awk '{print int($1 + 0.5)}')
    else
        rr="unknown"
    fi

    echo "{\"profile\":\"$prof\",\"epp\":\"$epp\",\"boost\":\"$boost\",\"hwp_dyn_boost\":\"$hwp_dyn_boost\",\"online\":\"$ac_state\",\"refresh_rate\":\"$rr\",\"epp_mismatch\":\"$epp_mismatch\"}"
}

# Initial read
read_state

# Event-driven primary loop (inotify on platform_profile userspace writes)
(inotifywait -m -e modify /sys/firmware/acpi/platform_profile 2>/dev/null || true) | while read -r _; do
    read_state
done &

# 5-second polling fallback loop (reconciles driver/desktop events that bypass inotify)
while true; do
    sleep 5
    read_state
done
