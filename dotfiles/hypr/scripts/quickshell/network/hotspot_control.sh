#!/usr/bin/env bash
#
# hotspot_control.sh -- NetworkManager Hotspot manager for QuickShell
# Fully robust against duplicate profile names using unique UUID matching,
# supports editing SSID/password live, client tracking, and clean Wi-Fi restore.
#
set -euo pipefail

IFACE=$(LC_ALL=C nmcli -t -f DEVICE,TYPE d 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')
[ -z "$IFACE" ] && IFACE="${HOTSPOT_IFACE:-wlo1}"

# Return the UUID of an active AP connection, or empty
get_active_hotspot_conn() {
    while IFS=: read -r uuid type; do
        [ -z "$uuid" ] && continue
        if [ "$type" = "802-11-wireless" ]; then
            mode=$(nmcli -s -g 802-11-wireless.mode connection show "$uuid" 2>/dev/null || true)
            if [ "$mode" = "ap" ]; then
                echo "$uuid"
                return 0
            fi
        fi
    done < <(nmcli -t -f UUID,TYPE connection show --active 2>/dev/null)
}

# Return the UUID of any existing AP connection, or empty
get_hotspot_conn() {
    while IFS=: read -r uuid type; do
        [ -z "$uuid" ] && continue
        if [ "$type" = "802-11-wireless" ]; then
            mode=$(nmcli -s -g 802-11-wireless.mode connection show "$uuid" 2>/dev/null || true)
            if [ "$mode" = "ap" ]; then
                echo "$uuid"
                return 0
            fi
        fi
    done < <(nmcli -t -f UUID,TYPE connection show 2>/dev/null)
}

start_hotspot() {
    # Save currently connected Wi-Fi SSID to restore it when Hotspot stops
    CURRENT_WIFI=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')
    if [ -n "$CURRENT_WIFI" ]; then
        echo "$CURRENT_WIFI" > "$HOME/.cache/wifi_pre_hotspot_ssid"
    fi

    existing_uuid=$(get_hotspot_conn)
    if [ -n "$existing_uuid" ]; then
        nmcli connection up uuid "$existing_uuid" >/dev/null 2>&1
    else
        nmcli device wifi hotspot ifname "$IFACE" ssid "NixOS-Hotspot" password "12345678" >/dev/null 2>&1
    fi
    notify-send -a "Hotspot" -i "network-wireless-hotspot" "Hotspot" "ON"
}

stop_hotspot() {
    active_uuid=$(get_active_hotspot_conn)
    if [ -n "$active_uuid" ]; then
        nmcli connection down uuid "$active_uuid" >/dev/null 2>&1
    fi
    # Restore previous Wi-Fi connection
    PREV_SSID=$(cat "$HOME/.cache/wifi_pre_hotspot_ssid" 2>/dev/null || echo "")
    rm -f "$HOME/.cache/wifi_pre_hotspot_ssid"
    if [ -n "$PREV_SSID" ] && nmcli connection show "$PREV_SSID" >/dev/null 2>&1; then
        nmcli connection up "$PREV_SSID" >/dev/null 2>&1 &
    else
        nmcli device connect "$IFACE" >/dev/null 2>&1 &
    fi
    notify-send -a "Hotspot" -i "network-wireless-offline" "Hotspot" "OFF"
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
        active_uuid=$(get_active_hotspot_conn)
        existing_uuid=$(get_hotspot_conn)
        
        is_active="false"
        ssid=""
        password=""
        clients=0
        devices_json="[]"
        
        target_uuid="${active_uuid:-$existing_uuid}"
        
        if [ -n "$active_uuid" ]; then
            is_active="true"
            clients=$(get_clients_count)
            devices_json=$(get_devices_json)
        fi
        
        if [ -n "$target_uuid" ]; then
            ssid=$(nmcli -s -g 802-11-wireless.ssid connection show "$target_uuid" 2>/dev/null || true)
            password=$(nmcli -s -g 802-11-wireless-security.psk connection show "$target_uuid" 2>/dev/null || true)
        fi
        
        [ -z "$ssid" ] && ssid="NixOS-Hotspot"
        
        cat <<EOF
{"active":$is_active,"iface":"$IFACE","ssid":"$ssid","password":"$password","clients":$clients,"devices":$devices_json}
EOF
        ;;
        
    --toggle)
        active_uuid=$(get_active_hotspot_conn)
        if [ -n "$active_uuid" ]; then
            stop_hotspot
        else
            start_hotspot
        fi
        ;;
        
    --start)
        start_hotspot
        ;;
        
    --stop)
        stop_hotspot
        ;;
        
    --set-ssid)
        new_ssid="${2:-}"
        existing_uuid=$(get_hotspot_conn)
        if [ -n "$new_ssid" ]; then
            if [ -n "$existing_uuid" ]; then
                nmcli connection modify uuid "$existing_uuid" 802-11-wireless.ssid "$new_ssid"
                # If currently active, re-up connection to apply SSID live
                if [ -n "$(get_active_hotspot_conn)" ]; then
                    nmcli connection up uuid "$existing_uuid" >/dev/null 2>&1 &
                fi
            else
                nmcli device wifi hotspot ifname "$IFACE" ssid "$new_ssid" >/dev/null 2>&1
            fi
            notify-send -a "Hotspot" -i "dialog-information" "Hotspot SSID Updated" "New SSID: $new_ssid"
        fi
        ;;
        
    --set-password)
        new_pass="${2:-}"
        existing_uuid=$(get_hotspot_conn)
        if [ -n "$new_pass" ]; then
            if [ -n "$existing_uuid" ]; then
                nmcli connection modify uuid "$existing_uuid" 802-11-wireless-security.psk "$new_pass"
                # If currently active, re-up connection to apply password live
                if [ -n "$(get_active_hotspot_conn)" ]; then
                    nmcli connection up uuid "$existing_uuid" >/dev/null 2>&1 &
                fi
            fi
            notify-send -a "Hotspot" -i "dialog-information" "Hotspot Security" "Password updated"
        fi
        ;;
        
    *)
        echo "Usage: $0 {--json|--toggle|--start|--stop|--set-ssid <ssid>|--set-password <pass>}"
        exit 1
        ;;
esac
