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
            \"eq_band_1_l:Gain\", $b1, \"eq_band_1_r:Gain\", $b1, \
            \"eq_band_2_l:Gain\", $b2, \"eq_band_2_r:Gain\", $b2, \
            \"eq_band_3_l:Gain\", $b3, \"eq_band_3_r:Gain\", $b3, \
            \"eq_band_4_l:Gain\", $b4, \"eq_band_4_r:Gain\", $b4, \
            \"eq_band_5_l:Gain\", $b5, \"eq_band_5_r:Gain\", $b5, \
            \"eq_band_6_l:Gain\", $b6, \"eq_band_6_r:Gain\", $b6, \
            \"eq_band_7_l:Gain\", $b7, \"eq_band_7_r:Gain\", $b7, \
            \"eq_band_8_l:Gain\", $b8, \"eq_band_8_r:Gain\", $b8, \
            \"eq_band_9_l:Gain\", $b9, \"eq_band_9_r:Gain\", $b9, \
            \"eq_band_10_l:Gain\", $b10, \"eq_band_10_r:Gain\", $b10 \
        ] }" >/dev/null 2>&1
    fi
}

cmd=$1
arg1=$2
arg2=$3

if [ "$cmd" != "get" ]; then
    exec 200>"${QS_RUN_MUSIC}/equalizer.lock"
    flock 200
fi

case $cmd in
"--init")
    if [ ! -f "$STATE_FILE" ]; then
        save_preset 0 0 0 0 0 0 0 0 0 0 "Off"
    fi
    apply_eq
    CUR_PRESET=$(jq -r '.preset // "Off"' "$STATE_FILE" 2>/dev/null || echo "Off")
    case "$CUR_PRESET" in
        "Karaoke"*) "$(dirname "${BASH_SOURCE[0]}")/../../karaoke.sh" on 2>/dev/null || true ;;
        *)          "$(dirname "${BASH_SOURCE[0]}")/../../karaoke.sh" off 2>/dev/null || true ;;
    esac
    ;;
"get")
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE" 2>/dev/null || echo '{"b1":0,"b2":0,"b3":0,"b4":0,"b5":0,"b6":0,"b7":0,"b8":0,"b9":0,"b10":0,"preset":"Off","pending":false}'
    else
        echo '{"b1":0,"b2":0,"b3":0,"b4":0,"b5":0,"b6":0,"b7":0,"b8":0,"b9":0,"b10":0,"preset":"Off","pending":false}'
    fi
    ;;
"set_band")
    tmp=$(cat "$STATE_FILE" 2>/dev/null)
    [ -z "$tmp" ] && tmp='{"b1":0,"b2":0,"b3":0,"b4":0,"b5":0,"b6":0,"b7":0,"b8":0,"b9":0,"b10":0,"preset":"Off","pending":false}'
    updated=$(echo "$tmp" | jq -c --argjson val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = false")
    echo "$updated" > "$STATE_FILE"
    EQ_NODE_ID=$(get_node_id)
    if [ -n "$EQ_NODE_ID" ]; then
        pw-cli s "$EQ_NODE_ID" Props "{ \"params\": [ \"eq_band_${arg1}_l:Gain\", $arg2, \"eq_band_${arg1}_r:Gain\", $arg2 ] }" >/dev/null 2>&1
    fi
    "$(dirname "${BASH_SOURCE[0]}")/../../karaoke.sh" off 2>/dev/null || true
    ;;
"apply")
    tmp=$(cat "$STATE_FILE" 2>/dev/null)
    [ -n "$tmp" ] && echo "$tmp" | jq -c ".pending = false" > "$STATE_FILE"
    apply_eq
    "$(dirname "${BASH_SOURCE[0]}")/../../karaoke.sh" off 2>/dev/null || true
    ;;
"preset")
    case $arg1 in
        "Off"|"Flat") save_preset 0 0 0 0 0 0 0 0 0 0 "Off" ;;
        "Bass")    save_preset 3 4 2 0 -1 0 1 1 1 1 "Bass" ;;
        "Karaoke") save_preset 0 0 0 0 -2 -3 -2 0 1 1 "Karaoke" ;;
        "Vocal")   save_preset -2 -1 1 3 5 5 4 2 1 0 "Vocal" ;;
        "Pop")     save_preset 1 2 1 -1 0 2 2 2 2 1 "Pop" ;;
        "Rock")    save_preset 2 2 1 -1 -1 1 2 2 3 2 "Rock" ;;
        "Jazz")    save_preset 1 1 1 1 2 2 2 2 1 1 "Jazz" ;;
        "Classic") save_preset 1 1 0 0 1 1 1 2 2 2 "Classic" ;;
    esac
    apply_eq
    case "$arg1" in
        "Karaoke") "$(dirname "${BASH_SOURCE[0]}")/../../karaoke.sh" on 2>/dev/null || true ;;
        *)         "$(dirname "${BASH_SOURCE[0]}")/../../karaoke.sh" off 2>/dev/null || true ;;
    esac
    ;;
esac
