#!/usr/bin/env bash
set -euo pipefail

generate_mock_json() {
    local count=${1:-25}
    local items=()
    for i in $(seq 1 "$count"); do
        local sig=$(( (i * 37) % 75 + 25 ))
        local sec="WPA2"
        [ $(( i % 3 )) -eq 0 ] && sec="WPA3"
        [ $(( i % 5 )) -eq 0 ] && sec="Open"
        items+=("{\"id\":\"FakeNetwork_$i\",\"ssid\":\"FakeNetwork_$i\",\"bssid\":\"00:11:22:33:44:$(printf '%02x' "$i")\",\"icon\":\"󰤨\",\"signal\":\"$sig\",\"security\":\"$sec\"}")
    done
    local net_joined
    net_joined=$(IFS=,; echo "${items[*]}")
    echo "{\"present\":true,\"power\":\"on\",\"connected\":{\"id\":\"PrimaryNet\",\"ssid\":\"PrimaryNet\",\"icon\":\"󰤨\",\"signal\":\"95\",\"security\":\"WPA2\",\"ip\":\"192.168.1.100\",\"freq\":\"5GHz\"},\"networks\":[$net_joined]}"
}

echo "Generating mock JSON with 25 networks:"
MOCK_DATA=$(generate_mock_json 25)
echo "Total mock networks count: $(echo "$MOCK_DATA" | jq '.networks | length')"
echo "Sample network entry: $(echo "$MOCK_DATA" | jq -c '.networks[0]')"
