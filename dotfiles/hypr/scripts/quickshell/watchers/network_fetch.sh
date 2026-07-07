# ==> /home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/watchers/network_fetch.sh <==
#!/usr/bin/env bash

get_wifi_radio() {
    LC_ALL=C nmcli radio wifi 2>/dev/null
}

get_wifi_strength() {
    local signal=$(LC_ALL=C awk 'NR==3 {gsub(/\./,"",$3); print int($3 * 100 / 70)}' /proc/net/wireless 2>/dev/null)
    echo "${signal:-0}"
}

get_network_data() {
    # Fetch NM layout exactly once via singular D-Bus query
    local NM_DUMP
    NM_DUMP=$(LC_ALL=C nmcli -t -f DEVICE,TYPE,STATE,CONNECTION d 2>/dev/null)

    local active_iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
    local iface_type=""

    if [ -n "$active_iface" ]; then
        iface_type=$(echo "$NM_DUMP" | awk -F: -v dev="$active_iface" '$1==dev {print $2; exit}')
    fi

    local status=""
    local ssid=""
    local icon=""
    local eth_status="Disconnected"

    if [ "$iface_type" = "ethernet" ]; then
        status="enabled"
        ssid="Ethernet"
        icon="󰈀"
        eth_status="Connected"

    elif [ "$iface_type" = "wifi" ]; then
        status="enabled"
        # Extract connection profile mapped directly to device from the dump
        ssid=$(echo "$NM_DUMP" | awk -F: -v dev="$active_iface" '$1==dev {print $4; exit}')
        if [ -z "$ssid" ]; then
            ssid=$(LC_ALL=C iw dev "$active_iface" link 2>/dev/null | awk '/\s+SSID/ { $1=""; sub(/^ /, ""); print; exit }')
        fi
        
        local signal=$(get_wifi_strength)
        if [ "$signal" -ge 75 ]; then icon="󰤨"
        elif [ "$signal" -ge 50 ]; then icon="󰤥"
        elif [ "$signal" -ge 25 ]; then icon="󰤢"
        else icon="󰤟"; fi

        local eth_dev=$(echo "$NM_DUMP" | awk -F: '$2=="ethernet" && $3=="connected" && $1 != "lo" {print $1; exit}')
        if [ -n "$eth_dev" ]; then eth_status="Connected"; fi

    else
        local radio=$(get_wifi_radio)
        local wifi_dev=$(echo "$NM_DUMP" | awk -F: '$2=="wifi" {print $1; exit}')

        if [ -z "$wifi_dev" ]; then
            status="disabled"
            ssid=""
            icon="󰈂"
        elif [ "$radio" = "disabled" ]; then
            status="disabled"
            ssid=""
            icon="󰤮"
        else
            status="enabled"
            ssid=""
            icon="󰤯"
        fi
    fi

    echo "$status|$ssid|$icon|$eth_status"
}

toggle_wifi() {
    if [ "$(get_wifi_radio)" = "enabled" ]; then
        LC_ALL=C nmcli radio wifi off
        notify-send -u low -i network-wireless-disabled "WiFi" "Disabled"
    else
        LC_ALL=C nmcli radio wifi on
        notify-send -u low -i network-wireless-enabled "WiFi" "Enabled"
    fi
}

case ${1:-} in
    --toggle) toggle_wifi ;;
    *)
        IFS='|' read -r status ssid icon eth <<< "$(get_network_data)"
        jq -n -c \
            --arg status "$status" \
            --arg ssid "$ssid" \
            --arg icon "$icon" \
            --arg eth "$eth" \
            '{status: $status, ssid: $ssid, icon: $icon, eth_status: $eth}' ;;
esac