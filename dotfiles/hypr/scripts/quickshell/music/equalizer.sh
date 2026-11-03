#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "music"

STATE_FILE="${QS_STATE_MUSIC:-$QS_RUN_MUSIC}/eq_state.json"

get_node_id() {
    pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_input.eq10"/ {gsub(/,/, "", id); print id}'
}

save_preset() {
    jq -n -c --arg b1 "$1" --arg b2 "$2" --arg b3 "$3" --arg b4 "$4" --arg b5 "$5" \
          --arg b6 "$6" --arg b7 "$7" --arg b8 "$8" --arg b9 "$9" --arg b10 "${10}" --arg p "${11}" \
       '{"b1": ($b1|tonumber), "b2": ($b2|tonumber), "b3": ($b3|tonumber), "b4": ($b4|tonumber), "b5": ($b5|tonumber), "b6": ($b6|tonumber), "b7": ($b7|tonumber), "b8": ($b8|tonumber), "b9": ($b9|tonumber), "b10": ($b10|tonumber), "preset": $p, "pending": false}' > "$STATE_FILE"
}

apply_eq() {
    [ ! -f "$STATE_FILE" ] && return
    vals=$(cat "$STATE_FILE" 2>/dev/null)
    [ -z "$vals" ] && return

    b1=$(echo "$vals" | jq -r '.b1 // 0')
    b2=$(echo "$vals" | jq -r '.b2 // 0')
    b3=$(echo "$vals" | jq -r '.b3 // 0')
    b4=$(echo "$vals" | jq -r '.b4 // 0')
    b5=$(echo "$vals" | jq -r '.b5 // 0')
    b6=$(echo "$vals" | jq -r '.b6 // 0')
    b7=$(echo "$vals" | jq -r '.b7 // 0')
    b8=$(echo "$vals" | jq -r '.b8 // 0')
    b9=$(echo "$vals" | jq -r '.b9 // 0')
    b10=$(echo "$vals" | jq -r '.b10 // 0')

    EQ_NODE_ID=$(get_node_id)
    if [ -n "$EQ_NODE_ID" ]; then
        pw-cli s "$EQ_NODE_ID" Props "{ \"params\": [ \
            \"eq_band_1:Gain\", $b1, \
            \"eq_band_2:Gain\", $b2, \
            \"eq_band_3:Gain\", $b3, \
            \"eq_band_4:Gain\", $b4, \
            \"eq_band_5:Gain\", $b5, \
            \"eq_band_6:Gain\", $b6, \
            \"eq_band_7:Gain\", $b7, \
            \"eq_band_8:Gain\", $b8, \
            \"eq_band_9:Gain\", $b9, \
            \"eq_band_10:Gain\", $b10 \
        ] }" >/dev/null 2>&1
    fi
}

cmd=$1
arg1=$2
arg2=$3

case $cmd in
"--init")
    if [ ! -f "$STATE_FILE" ]; then
        save_preset 0 0 0 0 0 0 0 0 0 0 "Flat"
    fi
    EQ_NODE_ID=$(get_node_id)
    if [ -n "$EQ_NODE_ID" ]; then
        wpctl set-default "$EQ_NODE_ID" 2>/dev/null || true
    fi
    apply_eq
    ;;
"get")
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo '{"b1":0,"b2":0,"b3":0,"b4":0,"b5":0,"b6":0,"b7":0,"b8":0,"b9":0,"b10":0,"preset":"Flat","pending":false}'
    fi
    ;;
"set_band")
    tmp=$(cat "$STATE_FILE" 2>/dev/null)
    [ -z "$tmp" ] && tmp='{"b1":0,"b2":0,"b3":0,"b4":0,"b5":0,"b6":0,"b7":0,"b8":0,"b9":0,"b10":0,"preset":"Flat","pending":false}'
    updated=$(echo "$tmp" | jq -c --argjson val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = false")
    echo "$updated" > "$STATE_FILE"
    EQ_NODE_ID=$(get_node_id)
    if [ -n "$EQ_NODE_ID" ]; then
        pw-cli s "$EQ_NODE_ID" Props "{ \"params\": [ \"eq_band_${arg1}:Gain\", $arg2 ] }" >/dev/null 2>&1
    fi
    ;;
"apply")
    tmp=$(cat "$STATE_FILE" 2>/dev/null)
    [ -n "$tmp" ] && echo "$tmp" | jq -c ".pending = false" > "$STATE_FILE"
    apply_eq
    ;;
"preset")
    case $arg1 in
        "Flat")    save_preset 0 0 0 0 0 0 0 0 0 0 "Flat" ;;
        "Bass")    save_preset 4 5 3 0 -1 0 1 1 2 1 "Bass" ;;
        "Treble")  save_preset -2 -1 0 0 1 2 3 4 5 4 "Treble" ;;
        "Vocal")   save_preset -3 -2 -1 1 3 4 3 2 1 0 "Vocal" ;;
        "Pop")     save_preset 2 3 1 -1 0 2 3 3 2 2 "Pop" ;;
        "Rock")    save_preset 4 3 1 -2 -1 1 2 3 4 3 "Rock" ;;
        "Jazz")    save_preset 2 2 1 1 2 2 2 2 1 1 "Jazz" ;;
        "Classic") save_preset 1 1 0 0 1 1 1 2 3 3 "Classic" ;;
    esac
    apply_eq
    ;;
esac
