#!/usr/bin/env bash
#
# battery_audit.sh -- Intelligent Continuous Battery Drainage Pattern Analyzer
#
# Tracks real-time power draw from /sys/class/power_supply/BAT0, attributes energy
# consumption (Wh) using CPU-time weighting; per-app Wh is modeled, not measured.
# detects power spikes, and provides balanced-mode optimization diagnostics.
#
# Pure Bash + awk + jq. Zero Python, zero Node.
#

set -uo pipefail

STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}/power/battery_audit"
mkdir -p "$STATE_DIR" "$STATE_DIR/history"

SESSION_FILE="$STATE_DIR/session.json"
PREV_TICKS_FILE="$STATE_DIR/prev_ticks.tmp"
LOCK_FILE="/tmp/battery_audit.lock"
PID_FILE="$STATE_DIR/daemon.pid"

SAMPLE_INTERVAL=60 # seconds between samples while discharging; elapsed-time totals use actual timestamps
IDLE_BASELINE_W=4.5 # estimated static baseline (OLED panel, motherboard, RAM)

# Helper: Map comm/executable to a clean canonical app name
canonical_app_name() {
    local comm="$1"
    case "$comm" in
        brave*|chrome*|chromium*) echo "Brave Browser" ;;
        zen*|firefox*)            echo "Zen Browser" ;;
        antigravity*)             echo "Antigravity IDE" ;;
        language_server*|rust-analyzer*|gopls*|pyright*) echo "IDE Language Servers" ;;
        pipewire*|wireplumber*)   echo "PipeWire Audio System" ;;
        cava)                     echo "Cava Visualizer" ;;
        *Hyprland*|hyprland*)     echo "Hyprland Compositor" ;;
        *quickshell*|qs*)         echo "QuickShell Desktop UI" ;;
        hyprpaper*|hyprsunset*|hypridle*|hyprlock*) echo "Hyprland Utilities" ;;
        xdg-desktop-portal*)      echo "XDG Desktop Portal" ;;
        alacritty*|kitty*|foot*)  echo "Terminal" ;;
        zsh|bash|sh)              echo "Shell" ;;
        systemd*|dbus*|udevd*)    echo "System Daemons" ;;
        tlp*|asusd*)              echo "Power Management Daemons" ;;
        kworker*|ksoftirqd*)      echo "Kernel Workers" ;;
        *)                        echo "$comm" ;;
    esac
}

# Read current battery status, power draw in Watts, capacity, energy in Wh
get_battery_metrics() {
    local bat_path="/sys/class/power_supply/BAT0"
    [ -d "$bat_path" ] || return 1

    local status="Unknown"
    local power_uw=0
    local energy_uw=0
    local cap=100

    [ -r "$bat_path/status" ] && status=$(cat "$bat_path/status" 2>/dev/null || echo "Unknown")
    [ -r "$bat_path/power_now" ] && power_uw=$(cat "$bat_path/power_now" 2>/dev/null || echo 0)
    [ -r "$bat_path/energy_now" ] && energy_uw=$(cat "$bat_path/energy_now" 2>/dev/null || echo 0)
    [ -r "$bat_path/capacity" ] && cap=$(cat "$bat_path/capacity" 2>/dev/null || echo 100)

    # If power_now is 0 or missing, compute from voltage_now and current_now if present
    if [ "$power_uw" -eq 0 ] && [ -r "$bat_path/current_now" ] && [ -r "$bat_path/voltage_now" ]; then
        local cur_ua volt_uv
        cur_ua=$(cat "$bat_path/current_now" 2>/dev/null || echo 0)
        volt_uv=$(cat "$bat_path/voltage_now" 2>/dev/null || echo 0)
        power_uw=$(awk "BEGIN { printf \"%.0f\", ($cur_ua * $volt_uv) / 1000000 }")
    fi

    # Output: status power_w energy_wh capacity
    awk -v s="$status" -v p="$power_uw" -v e="$energy_uw" -v c="$cap" '
    BEGIN {
        power_w = p / 1000000.0;
        energy_wh = e / 1000000.0;
        printf "%s %.2f %.2f %d\n", s, power_w, energy_wh, c;
    }'
}

# Single sampling and accumulation step
sample_step() {
    read -r status power_w energy_wh capacity <<< "$(get_battery_metrics)"

    local now_epoch
    now_epoch=$(date +%s)

    # If on AC or not discharging
    if [ "$status" != "Discharging" ]; then
        # If an active discharge session was running, archive it
        if [ -f "$SESSION_FILE" ] && [ -s "$SESSION_FILE" ]; then
            local dur
            dur=$(jq -r '.duration_seconds // 0' "$SESSION_FILE" 2>/dev/null || echo 0)
            if [ "$dur" -gt 60 ]; then
                cp -f "$SESSION_FILE" "$STATE_DIR/history/session_${now_epoch}.json"
            fi
            # Reset session file for fresh discharge cycle
            rm -f "$SESSION_FILE" "$PREV_TICKS_FILE"
        fi
        return 0
    fi

    # Initialize session state if missing
    if [ ! -f "$SESSION_FILE" ] || [ ! -s "$SESSION_FILE" ]; then
        cat <<EOF > "$SESSION_FILE"
{
  "start_epoch": $now_epoch,
  "last_epoch": $now_epoch,
  "duration_seconds": 0,
  "start_capacity": $capacity,
  "current_capacity": $capacity,
  "samples_count": 0,
  "total_energy_wh": 0.0,
  "avg_power_w": $power_w,
  "peak_power_w": $power_w,
  "min_power_w": $power_w,
  "apps": {},
  "spikes": []
}
EOF
    fi

    # Measure CPU ticks per process: collect comm and total user+system time in seconds
    local current_ticks_tmp="/tmp/bat_audit_cur_$$.tmp"
    ps -eo comm=,time= | awk '
    {
        comm = $1
        # Parse time format: [dd-]hh:mm:ss
        t = $2
        days = 0; hours = 0; mins = 0; secs = 0
        if (index(t, "-") > 0) {
            split(t, d_arr, "-")
            days = d_arr[1]
            t = d_arr[2]
        }
        n = split(t, parts, ":")
        if (n == 3) {
            hours = parts[1]; mins = parts[2]; secs = parts[3]
        } else if (n == 2) {
            mins = parts[1]; secs = parts[2]
        }
        tot_secs = (days * 86400) + (hours * 3600) + (mins * 60) + secs
        app_times[comm] += tot_secs
    }
    END {
        for (c in app_times) {
            printf "%s %.1f\n", c, app_times[c]
        }
    }' > "$current_ticks_tmp"

    # Compute deltas against previous sample
    local delta_json="{}"
    if [ -f "$PREV_TICKS_FILE" ]; then
        delta_json=$(awk '
        FILENAME == ARGV[1] { prev[$1] = $2; next }
        FILENAME == ARGV[2] {
            cur = $2;
            p = ($1 in prev) ? prev[$1] : cur;
            diff = cur - p;
            if (diff > 0.05) {
                # Map to canonical category
                comm = $1
                cname = comm
                if (comm ~ /^(brave|chrome|chromium)/) cname = "Brave Browser"
                else if (comm ~ /^(zen|firefox)/) cname = "Zen Browser"
                else if (comm ~ /^antigravity/) cname = "Antigravity IDE"
                else if (comm ~ /^(language_server|rust-analyzer|gopls|pyright)/) cname = "IDE Language Servers"
                else if (comm ~ /^(pipewire|wireplumber)/) cname = "PipeWire Audio System"
                else if (comm ~ /^cava$/) cname = "Cava Visualizer"
                else if (comm ~ /Hyprland/) cname = "Hyprland Compositor"
                else if (comm ~ /quickshell/) cname = "QuickShell Desktop UI"
                else if (comm ~ /^(hyprpaper|hyprsunset|hypridle|hyprlock)/) cname = "Hyprland Utilities"
                else if (comm ~ /^xdg-desktop-portal/) cname = "XDG Desktop Portal"
                else if (comm ~ /^(alacritty|kitty|foot)/) cname = "Terminal"
                else if (comm ~ /^(systemd|dbus-daemon|udevd)/) cname = "System Daemons"
                else if (comm ~ /^(tlp|asusd)/) cname = "Power Management Daemons"
                else if (comm ~ /^kworker/) cname = "Kernel Workers"

                app_diff[cname] += diff
                total_diff += diff
            }
        }
        END {
            printf "{\"total_diff\": %.2f, \"apps\": {", total_diff
            first = 1
            for (a in app_diff) {
                if (!first) printf ","
                printf "\"%s\": %.2f", a, app_diff[a]
                first = 0
            }
            printf "}}\n"
        }' "$PREV_TICKS_FILE" "$current_ticks_tmp")
    else
        delta_json="{\"total_diff\": 0.0, \"apps\": {}}"
    fi

    mv -f "$current_ticks_tmp" "$PREV_TICKS_FILE"

    # Energy consumed in this interval:
    # E_step = power_w * (interval_seconds / 3600) Wh
    local interval_sec=$SAMPLE_INTERVAL
    local last_epoch
    last_epoch=$(jq -r '.last_epoch // 0' "$SESSION_FILE" 2>/dev/null || echo 0)
    if [ "$last_epoch" -gt 0 ]; then
        local calc_int=$(( now_epoch - last_epoch ))
        [ "$calc_int" -ge 1 ] && [ "$calc_int" -le 120 ] && interval_sec=$calc_int
    fi

    # Update session JSON atomically using jq
    local updated_json
    updated_json=$(jq -n \
        --slurpfile session "$SESSION_FILE" \
        --argjson delta "$delta_json" \
        --argjson now "$now_epoch" \
        --argjson p "$power_w" \
        --argjson cap "$capacity" \
        --argjson int "$interval_sec" \
        --argjson baseline "$IDLE_BASELINE_W" \
    '
    ($session[0]) as $s |
    ($int / 3600.0) as $hrs |
    ($p * $hrs) as $e_step |
    (if $p > $baseline then ($p - $baseline) else 0.5 end) as $p_dyn |
    ($p_dyn * $hrs) as $e_dyn |
    ($e_step - $e_dyn) as $e_base |
    ($delta.total_diff) as $tot_cpu |

    # Update apps map
    ($s.apps // {}) as $cur_apps |
    (reduce ($delta.apps | to_entries)[] as $item (
        $cur_apps;
        ($item.key) as $k |
        ($item.value) as $v |
        (if $tot_cpu > 0 then ($v / $tot_cpu) * $e_dyn else 0 end) as $app_e |
        .[$k] = {
            "energy_wh": ((.[$k].energy_wh // 0) + $app_e),
            "cpu_seconds": ((.[$k].cpu_seconds // 0) + $v)
        }
    )) as $updated_apps |

    # Add display baseline attribution
    ($updated_apps | .["Display & SoC Baseline"] = {
        "energy_wh": ((.["Display & SoC Baseline"].energy_wh // 0) + $e_base),
        "cpu_seconds": ((.["Display & SoC Baseline"].cpu_seconds // 0))
    }) as $final_apps |

    # Check for high-drain spike (>16W)
    ($s.spikes // []) as $cur_spikes |
    (
        if $p >= 16.0 then
            # Find top active app in this step
            (($delta.apps | to_entries | sort_by(.value) | reverse | .[0].key) // "General Compute") as $top_cause |
            $cur_spikes + [{
                "time": ($now | todate),
                "power_w": $p,
                "top_app": $top_cause
            }] | .[-20:] # Keep last 20 spikes
        else
            $cur_spikes
        end
    ) as $updated_spikes |

    ($s.samples_count + 1) as $new_count |
    ($s.total_energy_wh + $e_step) as $new_e |
    (($s.duration_seconds // 0) + $int) as $new_dur |
    ((($s.avg_power_w * $s.samples_count) + $p) / $new_count) as $new_avg |
    (if $p > ($s.peak_power_w // 0) then $p else $s.peak_power_w end) as $new_peak |
    (if ($s.min_power_w // 999) > $p and $p > 1.0 then $p else ($s.min_power_w // $p) end) as $new_min |

    {
        "start_epoch": $s.start_epoch,
        "last_epoch": $now,
        "duration_seconds": $new_dur,
        "start_capacity": $s.start_capacity,
        "current_capacity": $cap,
        "samples_count": $new_count,
        "total_energy_wh": ( $new_e * 1000 | round / 1000 ),
        "avg_power_w": ( $new_avg * 100 | round / 100 ),
        "peak_power_w": ( $new_peak * 100 | round / 100 ),
        "min_power_w": ( $new_min * 100 | round / 100 ),
        "apps": $final_apps,
        "spikes": $updated_spikes
    }
    ')

    if [ -n "$updated_json" ]; then
        echo "$updated_json" > "$SESSION_FILE.tmp" && mv -f "$SESSION_FILE.tmp" "$SESSION_FILE"
    fi
}

# Daemon loop
run_daemon() {
    exec 8>"$LOCK_FILE"
    if ! flock -n 8; then
        echo "Battery audit daemon already running."
        exit 0
    fi
    echo "$$" > "$PID_FILE"

    trap 'rm -f "$LOCK_FILE" "$PID_FILE" "$PREV_TICKS_FILE"; exit 0' SIGTERM SIGINT EXIT

    while true; do
        sample_step 2>/dev/null || true
        # If discharging, sample every SAMPLE_INTERVAL; if plugged in, check every 45s.
        local status
        status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
        if [ "$status" = "Discharging" ]; then
            sleep "$SAMPLE_INTERVAL"
        else
            sleep 45
        fi
    done
}

# Generate rich analytical report
generate_report() {
    read -r status power_w energy_wh capacity <<< "$(get_battery_metrics)"

    if [ ! -f "$SESSION_FILE" ] || [ ! -s "$SESSION_FILE" ]; then
        echo -e "\e[1;33m[!] No continuous discharge session recorded yet.\e[0m"
        echo -e "Starting immediate 5-second baseline analysis..."
        sample_step 2>/dev/null || true
        sleep 5
        sample_step 2>/dev/null || true
    fi

    local session_data
    session_data=$(cat "$SESSION_FILE" 2>/dev/null || echo "{}")

    local dur start_cap cur_cap avg_p peak_p min_p tot_e
    dur=$(echo "$session_data" | jq -r '.duration_seconds // 0')
    start_cap=$(echo "$session_data" | jq -r '.start_capacity // 100')
    cur_cap=$(echo "$session_data" | jq -r '.current_capacity // 100')
    avg_p=$(echo "$session_data" | jq -r '.avg_power_w // 0')
    peak_p=$(echo "$session_data" | jq -r '.peak_power_w // 0')
    min_p=$(echo "$session_data" | jq -r '.min_power_w // 0')
    tot_e=$(echo "$session_data" | jq -r '.total_energy_wh // 0')

    local hrs=$(( dur / 3600 ))
    local mins=$(( (dur % 3600) / 60 ))
    local secs=$(( dur % 60 ))
    local cap_drop=$(( start_cap - cur_cap ))
    [ "$cap_drop" -lt 0 ] && cap_drop=0

    # Calculate estimated runtime on full battery (57.7 Wh design full)
    local est_runtime_hrs="N/A"
    if (( $(echo "$avg_p > 1.0" | bc -l 2>/dev/null || echo 0) )); then
        est_runtime_hrs=$(awk -v avg="$avg_p" 'BEGIN { printf "%.1f", 57.7 / avg }')
    fi

    echo -e "\e[1;36m╔══════════════════════════════════════════════════════════════════════════════╗\e[0m"
    echo -e "\e[1;36m║                  BATTERY DRAINAGE PATTERN & CONSUMPTION AUDIT                ║\e[0m"
    echo -e "\e[1;36m╚══════════════════════════════════════════════════════════════════════════════╝\e[0m"
    echo ""
    echo -e "\e[1;32m● Session Overview (Balanced Mode Baseline):\e[0m"
    echo -e "  • State:              \e[1m$status\e[0m (${capacity}% remaining, ${energy_wh} Wh)"
    echo -e "  • Session Duration:   \e[1m${hrs}h ${mins}m ${secs}s\e[0m (Battery drop: \e[1;31m-${cap_drop}%\e[0m from ${start_cap}%)"
    echo -e "  • Real-time Draw:     \e[1m${power_w} W\e[0m"
    echo -e "  • Average Discharge:  \e[1;33m${avg_p} W\e[0m (Min: ${min_p} W, Peak Spike: \e[1;31m${peak_p} W\e[0m)"
    local formatted_e
    formatted_e=$(printf "%.3f" "$tot_e" 2>/dev/null || echo "$tot_e")
    echo -e "  • Energy Discharged:  \e[1m${formatted_e} Wh\e[0m"
    echo -e "  • Projected Full Run: \e[1;32m~${est_runtime_hrs} hours\e[0m (at current ${avg_p} W average)"
    echo ""

    echo -e "\e[1;32m● App Energy Drain Breakdown (Ranked by Wh Consumed):\e[0m"
    printf "  \e[1;37m%-28s %12s %12s %14s\e[0m\n" "APPLICATION / SUBSYSTEM" "ENERGY (Wh)" "% OF DRAIN" "ACTIVE CPU SEC"
    echo "  ──────────────────────────────────────────────────────────────────"

    echo "$session_data" | jq -r --argjson tot "$tot_e" '
    .apps // {} | to_entries
    | sort_by(.value.energy_wh) | reverse
    | .[] |
    (.value.energy_wh // 0) as $e |
    (.value.cpu_seconds // 0) as $cpu |
    (if $tot > 0 then ($e / $tot * 100) else 0 end) as $pct |
    [ .key, ( $e * 1000 | round / 1000 ), ( $pct * 10 | round / 10 ), ( $cpu * 10 | round / 10 ) ]
    | @tsv
    ' | while IFS=$'\t' read -r name e pct cpu; do
        local color="\e[0m"
        if (( $(echo "$pct >= 25.0" | bc -l 2>/dev/null || echo 0) )); then
            color="\e[1;31m" # Red for heavy drainers
        elif (( $(echo "$pct >= 10.0" | bc -l 2>/dev/null || echo 0) )); then
            color="\e[1;33m" # Yellow for moderate
        fi
        printf "  ${color}%-28s %10.3f Wh %11.1f%% %12.1fs\e[0m\n" "$name" "$e" "$pct" "$cpu"
    done
    echo ""

    # Spikes breakdown
    local spike_count
    spike_count=$(echo "$session_data" | jq '.spikes | length')
    if [ "$spike_count" -gt 0 ]; then
        echo -e "\e[1;31m● High-Drain Power Spikes Detected (>16W):\e[0m"
        echo "$session_data" | jq -r '.spikes[-5:][] | "  • [\(.time)] Power surged to \(.power_w) W — Offender: \(.top_app)"'
        echo ""
    fi

    # Targeted balanced mode optimization insights
    echo -e "\e[1;35m● Balanced Mode Performance & Battery Recommendations:\e[0m"
    
    # 1. Check Cava visualizer
    if pgrep -x cava >/dev/null 2>&1; then
        echo -e "  \e[1;33m[!]\e[0m \e[1mCava Visualizer Active:\e[0m cava renders audio FFT continuously (~3-4% CPU). Muting or auto-stopping cava when idle saves ~0.8W."
    fi

    # 2. Check Brave Hardware Acceleration
    if pgrep -f "brave.*type=renderer" >/dev/null 2>&1; then
        local high_cpu_brave
        high_cpu_brave=$(ps -eo comm,%cpu --sort=-%cpu | awk '$1 ~ /brave/ && $2 > 20.0 {print $2; exit}')
        if [ -n "$high_cpu_brave" ]; then
            echo -e "  \e[1;31m[!]\e[0m \e[1mBrave Software Video Decode Spike ($high_cpu_brave% CPU):\e[0m Ensure VA-API GPU video decode is active ('--enable-features=VaapiVideoDecodeLinuxGL'). Software decoding 1080p60 on i5-13500H draws 12-18W vs 5-7W with Iris Xe hardware decode."
        fi
    fi

    # 3. Check Display Refresh Rate
    local cur_rate
    cur_rate=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].refreshRate // 120')
    if (( $(echo "$cur_rate > 90" | bc -l 2>/dev/null || echo 0) )) && [ "$status" = "Discharging" ]; then
        echo -e "  \e[1;33m[!]\e[0m \e[1mDisplay at ${cur_rate}Hz on Battery:\e[0m Dropping to 60Hz saves ~1.2W on 2.8K OLED."
    fi

    # 4. Check OLED pure black efficiency
    echo -e "  \e[1;32m[✓]\e[0m \e[1mOLED Panel Pure Black:\e[0m Samsung 2.8K OLED emits 0W on '#000000'. Keep pitch-black wallpapers active on battery."

    echo ""
}

case "${1:-report}" in
    daemon)
        run_daemon
        ;;
    start)
        script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
            echo "Daemon already running (PID $(cat "$PID_FILE"))."
        else
            nohup bash "$script_path" daemon </dev/null >/dev/null 2>&1 &
            disown
            echo "Battery audit daemon started in background."
        fi
        ;;
    stop)
        if [ -f "$PID_FILE" ]; then
            kill "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null || true
            rm -f "$PID_FILE" "$LOCK_FILE"
            echo "Battery audit daemon stopped."
        else
            echo "Daemon not running."
        fi
        ;;
    reset)
        rm -f "$SESSION_FILE" "$PREV_TICKS_FILE"
        echo "Battery audit session data cleared."
        ;;
    status)
        read -r s p e c <<< "$(get_battery_metrics)"
        echo "Battery: $c% ($s) | Power: ${p}W | Energy: ${e}Wh"
        ;;
    report)
        generate_report
        ;;
    *)
        echo "Usage: $0 {report|status|start|stop|daemon|reset}"
        exit 1
        ;;
esac
