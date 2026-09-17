#!/usr/bin/env bash
#
# hotspot_control.sh -- NetworkManager Hotspot manager for QuickShell
# Supports virtual ap0 for simultaneous STA/AP concurrency, editing SSID/password,
# and detailed connected device tracking.
#
set -euo pipefail

IFACE=$(LC_ALL=C nmcli -t -f DEVICE,TYPE d 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')
[ -z "$IFACE" ] && IFACE="${HOTSPOT_IFACE:-wlo1}"

get_hotspot_conn() {
    nmcli -t -f NAME,TYPE connection show | while IFS=: read -r name type; do
        if [ "$type" = "802-11-wireless" ]; then
            mode=$(nmcli -s -g 802-11-wireless.mode connection show "$name" 2>/dev/null || true)
            if [ "$mode" = "ap" ]; then
                echo "$name"
                return 0
            fi
        fi
    done
}

get_active_hotspot_conn() {
    nmcli -t -f NAME,TYPE connection show --active | while IFS=: read -r name type; do
        if [ "$type" = "802-11-wireless" ]; then
            mode=$(nmcli -s -g 802-11-wireless.mode connection show "$name" 2>/dev/null || true)
            if [ "$mode" = "ap" ]; then
                echo "$name"
                return 0
            fi
        fi
    done
}

get_clients_count() {
    local count
    count=$(iw dev "$IFACE" station dump 2>/dev/null | grep -c "^Station" || true)
    echo "$count"
}

get_devices_json() {
    local dev_json="[]"
    local lease_file=""
    
    for f in /var/lib/NetworkManager/dnsmasq-*.leases; do
        [ -f "$f" ] && lease_file="$f" && break
    done
    
    if [ -n "$lease_file" ] && [ -s "$lease_file" ]; then
        dev_json=$(awk 'BEGIN { printf "[" }
            {
                if (NR > 1) printf ",";
                mac = $2; ip = $3; name = ($4 == "*" ? "Device" : $4);
                printf "{\"mac\":\"%s\",\"ip\":\"%s\",\"name\":\"%s\"}", mac, ip, name;
            }
            END { printf "]" }' "$lease_file")
    else
        # Fallback to ip neigh
        dev_json=$(ip neigh show dev "$IFACE" 2>/dev/null | grep -v "FAILED" | awk 'BEGIN { printf "[" }
            {
                if (NR > 1) printf ",";
                ip = $1; mac = $5;
                printf "{\"mac\":\"%s\",\"ip\":\"%s\",\"name\":\"Connected Client\"}", mac, ip;
            }
            END { printf "]" }')
    fi
    [ -z "$dev_json" ] && dev_json="[]"
    echo "$dev_json"
}

cmd="${1:---json}"

case "$cmd" in
    --json)
        active_conn=$(get_active_hotspot_conn)
        existing_conn=$(get_hotspot_conn)
        
        is_active="false"
        ssid=""
        password=""
        clients=0
        devices_json="[]"
        
        target_conn="${active_conn:-$existing_conn}"
        
        if [ -n "$active_conn" ]; then
            is_active="true"
            clients=$(get_clients_count)
            devices_json=$(get_devices_json)
        fi
        
        if [ -n "$target_conn" ]; then
            ssid=$(nmcli -s -g 802-11-wireless.ssid connection show "$target_conn" 2>/dev/null || true)
            password=$(nmcli -s -g 802-11-wireless-security.psk connection show "$target_conn" 2>/dev/null || true)
        fi
        
        [ -z "$ssid" ] && ssid="NixOS-Hotspot"
        
        cat <<EOF
{"active":$is_active,"iface":"$IFACE","ssid":"$ssid","password":"$password","clients":$clients,"devices":$devices_json}
EOF
        ;;
        
    --toggle)
        active_conn=$(get_active_hotspot_conn)
        if [ -n "$active_conn" ]; then
            nmcli connection down "$active_conn" >/dev/null 2>&1
            notify-send -a "Hotspot" -i "network-wireless-offline" "Hotspot" "Hotspot disabled"
        else
            existing_conn=$(get_hotspot_conn)
            if [ -n "$existing_conn" ]; then
                nmcli connection up "$existing_conn" >/dev/null 2>&1
            else
                nmcli device wifi hotspot ifname "$IFACE" ssid "NixOS-Hotspot" >/dev/null 2>&1
            fi
            notify-send -a "Hotspot" -i "network-wireless-hotspot" "Hotspot" "Hotspot enabled"
        fi
        ;;
        
    --start)
        existing_conn=$(get_hotspot_conn)
        if [ -n "$existing_conn" ]; then
            nmcli connection up "$existing_conn" >/dev/null 2>&1
        else
            nmcli device wifi hotspot ifname "$IFACE" ssid "NixOS-Hotspot" >/dev/null 2>&1
        fi
        ;;
        
    --stop)
        active_conn=$(get_active_hotspot_conn)
        if [ -n "$active_conn" ]; then
            nmcli connection down "$active_conn" >/dev/null 2>&1
        fi
        ;;
        
    --set-ssid)
        new_ssid="${2:-}"
        existing_conn=$(get_hotspot_conn)
        if [ -n "$new_ssid" ]; then
            if [ -n "$existing_conn" ]; then
                nmcli connection modify "$existing_conn" 802-11-wireless.ssid "$new_ssid"
            else
                nmcli device wifi hotspot ifname "$IFACE" ssid "$new_ssid" >/dev/null 2>&1
            fi
            notify-send -a "Hotspot" -i "dialog-information" "Hotspot SSID Updated" "New SSID: $new_ssid"
        fi
        ;;
        
    --set-password)
        new_pass="${2:-}"
        existing_conn=$(get_hotspot_conn)
        if [ -n "$new_pass" ]; then
            if [ -n "$existing_conn" ]; then
                nmcli connection modify "$existing_conn" 802-11-wireless-security.psk "$new_pass"
            fi
            notify-send -a "Hotspot" -i "dialog-information" "Hotspot Security" "Password updated"
        fi
        ;;
        
    *)
        echo "Usage: $0 {--json|--toggle|--start|--stop|--set-ssid <ssid>|--set-password <pass>}"
        exit 1
        ;;
esac
