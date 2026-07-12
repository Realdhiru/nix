#!/usr/bin/env bash
# Applies an energy_performance_preference (EPP) value to every CPU core.
#
# This replaces `powerprofilesctl set` as the actual mechanism behind the
# Quickshell BatteryPopup profile picker. power-profiles-daemon is
# intentionally disabled system-wide (see modules/system/power.nix — TLP
# is the sole power manager), so `powerprofilesctl` has no daemon to talk
# to and was previously a silent no-op. EPP is the real per-core knob TLP
# itself drives via CPU_ENERGY_PERF_POLICY_ON_AC/BAT, so writing it
# directly here is consistent with the existing architecture and doesn't
# require re-enabling anything TLP conflicts with.
#
# Invoked via a single exact-path NOPASSWD sudoers rule (see users.nix).
# That rule does NOT pin the argument, because sudoers can't practically
# match a shell-glob-expanded file list that varies by core count across
# machines. Instead, this script is the security boundary: it whitelists
# the value before writing anything, so a NOPASSWD grant on "run this
# script with any argument" is safe.
set -euo pipefail

value="${1:-}"

case "$value" in
    performance|balance_performance|balance_power|power|default) ;;
    *)
        echo "set_epp.sh: rejected EPP value: '${value}'" >&2
        exit 1
        ;;
esac

wrote_any=0
for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/energy_performance_preference; do
    if [ -w "$f" ]; then
        echo "$value" > "$f"
        wrote_any=1
    fi
done

if [ "$wrote_any" -eq 0 ]; then
    echo "set_epp.sh: no writable energy_performance_preference files found" >&2
    exit 1
fi