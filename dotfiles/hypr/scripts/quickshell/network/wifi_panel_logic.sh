#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/../../caching.sh"
qs_ensure_cache "network"

# Zero-latency hardware presence check via sysfs (Instant, no nmcli hang)
if ! ls -1d /sys/class/net/*/wireless &>/dev/null; then
    echo '{ "present": false, "power": "off", "connected": null, "networks": [] }'
    exit 0
fi

POWER=$(LC_ALL=C nmcli radio wifi)

if [[ "$POWER" == "disabled" ]]; then
    echo '{ "present": true, "power": "off", "connected": null, "networks": [] }'
    exit 0
fi

get_icon() {
    local signal=$1
    if [[ $signal -ge 80 ]]; then echo "󰤨";
    elif [[ $signal -ge 60 ]]; then echo "󰤥";
    elif [[ $signal -ge 40 ]]; then echo "󰤢";
    elif [[ $signal -ge 20 ]]; then echo "󰤟";
    else echo "󰤯"; fi
}

CACHE_DIR="$QS_CACHE_NETWORK"
mkdir -p "$CACHE_DIR"

# Detect active Hotspot SSID so it is never presented as an external Wi-Fi network
HOTSPOT_SSID=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2=="802-11-wireless"{print $1}' | while read -r n; do
    if [ "$(nmcli -s -g 802-11-wireless.mode connection show "$n" 2>/dev/null)" = "ap" ]; then
        nmcli -s -g 802-11-wireless.ssid connection show "$n" 2>/dev/null
        break
    fi
done)

CURRENT_RAW=$(LC_ALL=C nmcli -t -f active,mode,ssid,signal,security device wifi | awk -F: -v hs="$HOTSPOT_SSID" '$1=="yes" && $2=="Infra" && (hs == "" || $3 != hs){print $1":"$3":"$4":"$5; exit}')

if [[ -n "$CURRENT_RAW" ]]; then
    IFS=':' read -r active ssid signal security <<< "$CURRENT_RAW"
    icon=$(get_icon "$signal")
    
    IFACE=$(LC_ALL=C nmcli -t -f DEVICE,TYPE,STATE d 2>/dev/null | awk -F: '$2=="wifi" && $3=="connected"{print $1;exit}')
    [ -z "$IFACE" ] && IFACE=$(LC_ALL=C nmcli -t -f DEVICE,TYPE d 2>/dev/null | awk -F: '$2=="wifi"{print $1;exit}')
    IP=$(ip -4 addr show dev "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    [ -z "$IP" ] && IP="No IP"
    
    FREQ=$(iw dev "$IFACE" link 2>/dev/null | awk '/freq:/ {print $2}')
    [ -n "$FREQ" ] && FREQ="${FREQ} MHz" || FREQ="Unknown"

    # Native Bash JSON generation
    ssid_esc="${ssid//\\/\\\\}"
    ssid_esc="${ssid_esc//\"/\\\"}"
    sec_esc="${security//\\/\\\\}"
    sec_esc="${sec_esc//\"/\\\"}"
    icon_esc="${icon//\\/\\\\}"
    icon_esc="${icon_esc//\"/\\\"}"
    CONNECTED_JSON="{\"id\":\"$ssid_esc\",\"ssid\":\"$ssid_esc\",\"icon\":\"$icon_esc\",\"signal\":\"$signal\",\"security\":\"$sec_esc\",\"ip\":\"$IP\",\"freq\":\"$FREQ\"}"
else
    ssid=""
    CONNECTED_JSON="null"
fi

# AWK processes the entire network list natively, zero sub-shells
# Excludes both connected SSID and the active hotspot SSID
NETWORKS_JSON=$(LC_ALL=C nmcli -t -f active,mode,ssid,signal,security device wifi list --rescan auto 2>/dev/null | awk -F: -v conn="$ssid" -v hs="$HOTSPOT_SSID" '
    $2 == "Infra" && $3 != "" && $3 != conn && (hs == "" || $3 != hs) && !seen[$3]++ {
        ssid=$3; signal=$4; security=$5;
        
        # Escape quotes and backslashes inside strings
        gsub(/\\/, "\\\\", ssid);
        gsub(/\\/, "\\\\", security);
        gsub(/"/, "\\\"", ssid);
        gsub(/"/, "\\\"", security);
        
        if (signal >= 80) icon="󰤨";
        else if (signal >= 60) icon="󰤥";
        else if (signal >= 40) icon="󰤢";
        else if (signal >= 20) icon="󰤟";
        else icon="󰤯";
        
        printf "{\"id\":\"%s\",\"ssid\":\"%s\",\"icon\":\"%s\",\"signal\":\"%s\",\"security\":\"%s\"}\n", ssid, ssid, icon, signal, security
    }
' | paste -sd, -)

if [ -z "$NETWORKS_JSON" ]; then
    NETWORKS_JSON="[]"
else
    NETWORKS_JSON="[$NETWORKS_JSON]"
fi

# Final JSON output
echo "{\"present\":true,\"power\":\"on\",\"connected\":$CONNECTED_JSON,\"networks\":$NETWORKS_JSON}"
