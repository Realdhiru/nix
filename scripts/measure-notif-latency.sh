#!/usr/bin/env bash
# scripts/measure-notif-latency.sh
# Precision notification latency measurement tool (ns/ms)
set -euo pipefail

TARGET="${1:-all}"
LOG_FILE="/tmp/notif_dbus_trace.log"
QS_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/quickshell/quickshell.log"

run_dbus_monitor() {
    rm -f "$LOG_FILE"
    dbus-monitor --session "type='method_call',interface='org.freedesktop.Notifications',member='Notify'" > "$LOG_FILE" 2>/dev/null &
    MON_PID=$!
    # Wait until dbus-monitor is attached
    sleep 0.15
}

stop_dbus_monitor() {
    kill "$MON_PID" 2>/dev/null || true
    wait "$MON_PID" 2>/dev/null || true
}

extract_dbus_time() {
    # Extract timestamp from dbus-monitor output
    grep -m 1 "method call time=" "$LOG_FILE" 2>/dev/null | sed -n 's/.*time=\([0-9.]*\).*/\1/p' || true
}

measure_command() {
    local label="$1"
    shift
    local cmd=("$@")

    quickshell ipc -p "$HOME/.config/hypr/scripts/quickshell/Shell.qml" call notif dismiss >/dev/null 2>&1 || true
    sleep 0.2
    run_dbus_monitor

    local qs_mark
    qs_mark=$(wc -l < "$QS_LOG" 2>/dev/null || echo 0)

    local t0 t1 t_dbus t_qs_recv t_qs_frame
    t0=$(date +%s%N)
    
    # Run the trigger command
    "${cmd[@]}" >/dev/null 2>&1 || true
    t1=$(date +%s%N)

    # Allow dbus and quickshell to finish processing
    sleep 0.2
    stop_dbus_monitor

    local dbus_sec
    dbus_sec=$(extract_dbus_time)
    if [ -n "$dbus_sec" ]; then
        # Convert dbus_sec (seconds.microseconds) to ns
        t_dbus=$(awk -v s="$dbus_sec" 'BEGIN { printf "%.0f", s * 1000000000 }')
    else
        t_dbus=0
    fi

    # Read QuickShell log since qs_mark
    local qs_tail
    qs_tail=$(tail -n +"$((qs_mark + 1))" "$QS_LOG" 2>/dev/null || true)
    
    # Look for [NOTIF_BENCH] in qs_tail if present
    local qs_ts
    qs_ts=$(echo "$qs_tail" | grep "NOTIF_BENCH.*RECEIVED" | tail -n 1 | sed -n 's/.*ts=\([0-9]*\).*/\1/p' || true)
    if [ -n "$qs_ts" ]; then
        t_qs_recv=$(awk -v s="$qs_ts" 'BEGIN { printf "%.0f", s * 1000000 }')
    else
        t_qs_recv=0
    fi

    local frame_ts
    frame_ts=$(echo "$qs_tail" | grep "NOTIF_BENCH.*FRAME" | tail -n 1 | sed -n 's/.*ts=\([0-9]*\).*/\1/p' || true)
    if [ -n "$frame_ts" ]; then
        t_qs_frame=$(awk -v s="$frame_ts" 'BEGIN { printf "%.0f", s * 1000000 }')
    else
        t_qs_frame=0
    fi

    local dur_script_ms dur_dbus_ms dur_recv_ms dur_frame_ms
    dur_script_ms=$(awk -v t0="$t0" -v t1="$t1" 'BEGIN { printf "%.2f", (t1 - t0) / 1000000 }')
    if [ "$t_dbus" -gt 0 ] && [ "$t_dbus" -ge "$t0" ]; then
        dur_dbus_ms=$(awk -v t0="$t0" -v td="$t_dbus" 'BEGIN { printf "%.2f", (td - t0) / 1000000 }')
    else
        dur_dbus_ms="N/A"
    fi

    if [ "$t_qs_recv" -gt 0 ] && [ "$t_qs_recv" -ge "$t0" ]; then
        dur_recv_ms=$(awk -v t0="$t0" -v tr="$t_qs_recv" 'BEGIN { printf "%.2f", (tr - t0) / 1000000 }')
    else
        dur_recv_ms="N/A"
    fi

    if [ "$t_qs_frame" -gt 0 ] && [ "$t_qs_frame" -ge "$t0" ]; then
        dur_frame_ms=$(awk -v t0="$t0" -v tf="$t_qs_frame" 'BEGIN { printf "%.2f", (tf - t0) / 1000000 }')
    else
        dur_frame_ms="N/A"
    fi

    echo "=== [$label] ==="
    echo "  T0 (trigger start):       $t0"
    echo "  T1 (script completion):   $t1 (total: ${dur_script_ms} ms)"
    echo "  T_DBUS (D-Bus Notify):    $t_dbus (from T0: ${dur_dbus_ms} ms)"
    echo "  T_QS (Ticker received):   $t_qs_recv (from T0: ${dur_recv_ms} ms)"
    echo "  T_FRAME (Rendered frame): $t_qs_frame (from T0: ${dur_frame_ms} ms)"
    echo ""
}

case "$TARGET" in
    plain)
        measure_command "Plain Notify" notify-send -a "Test" "Benchmark" "Plain"
        ;;
    volume)
        measure_command "Volume Up" bash "$HOME/nix/dotfiles/hypr/scripts/osd.sh" vol-up
        ;;
    coffee)
        measure_command "Coffee Toggle" bash "$HOME/nix/dotfiles/hypr/scripts/power.sh" inhibit
        ;;
    gaming)
        measure_command "Gaming Toggle" bash "$HOME/nix/dotfiles/hypr/scripts/toggle_gaming_mode.sh"
        ;;
    wallpaper-kill)
        measure_command "Wallpaper Kill" bash "$HOME/nix/dotfiles/wallpaper/wallpaper.sh" kill
        ;;
    all)
        measure_command "Plain Notify" notify-send -a "Test" "Benchmark" "Plain"
        sleep 1.5
        measure_command "Volume Up" bash "$HOME/nix/dotfiles/hypr/scripts/osd.sh" vol-up
        sleep 1.5
        measure_command "Coffee Toggle" bash "$HOME/nix/dotfiles/hypr/scripts/power.sh" inhibit
        sleep 1.5
        # Revert coffee toggle back to clean
        bash "$HOME/nix/dotfiles/hypr/scripts/power.sh" inhibit >/dev/null 2>&1 || true
        sleep 1.5
        measure_command "Gaming Toggle" bash "$HOME/nix/dotfiles/hypr/scripts/toggle_gaming_mode.sh"
        sleep 1.5
        # Revert gaming toggle back
        bash "$HOME/nix/dotfiles/hypr/scripts/toggle_gaming_mode.sh" >/dev/null 2>&1 || true
        sleep 1.5
        measure_command "Wallpaper Kill" bash "$HOME/nix/dotfiles/wallpaper/wallpaper.sh" kill
        sleep 1.5
        # Revert wallpaper kill back
        bash "$HOME/nix/dotfiles/wallpaper/wallpaper.sh" kill >/dev/null 2>&1 || true
        ;;
esac
