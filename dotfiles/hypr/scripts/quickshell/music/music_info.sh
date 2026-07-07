#!/usr/bin/env bash
# dotfiles/hypr/scripts/quickshell/music/music_info.sh

source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "music"

TMP_DIR="$QS_RUN_MUSIC/covers"
STATE_FILE="$QS_STATE_MUSIC/last_state.json"

mkdir -p "$TMP_DIR"
PLACEHOLDER="$TMP_DIR/placeholder_blank.png"

PT="timeout 1.5 playerctl"

if [ ! -f "$PLACEHOLDER" ]; then
    convert -size 500x500 xc:"#313244" "$PLACEHOLDER"
fi

STATUS=$($PT status 2>/dev/null)

format_time() {
    local s=$1
    if [ -z "$s" ]; then s=0; fi
    if [ "$s" -ge 3600 ]; then
        printf "%d:%02d:%02d" $((s/3600)) $(( (s%3600)/60 )) $((s%60))
    else
        printf "%02d:%02d" $((s/60)) $((s%60))
    fi
}

if [ "$STATUS" = "Playing" ] || [ "$STATUS" = "Paused" ]; then

    rawUrl=$($PT metadata mpris:artUrl 2>/dev/null)
    title=$($PT metadata xesam:title 2>/dev/null)
    artist=$($PT metadata xesam:artist 2>/dev/null)

    if [ -n "$rawUrl" ]; then
        trackHash=$(echo "$rawUrl" | md5sum | cut -d" " -f1)
    else
        idStr="${title:-unknown}-${artist:-unknown}"
        trackHash=$(echo "$idStr" | md5sum | cut -d" " -f1)
    fi

    finalArt="$TMP_DIR/${trackHash}_art.jpg"
    blurPath="$TMP_DIR/${trackHash}_blur.png"
    colorPath="$TMP_DIR/${trackHash}_grad.txt"
    textPath="$TMP_DIR/${trackHash}_text.txt"
    lockFile="$TMP_DIR/${trackHash}.lock"

    displayArt="$PLACEHOLDER"
    displayBlur="$PLACEHOLDER"
    displayGrad="linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)"
    displayText="#cdd6f4"

    if [ -f "$finalArt" ] && [ -s "$finalArt" ]; then
        displayArt="$finalArt"
        if [ -f "$blurPath" ]; then displayBlur="$blurPath"; fi
        if [ -f "$colorPath" ]; then displayGrad=$(cat "$colorPath"); fi
        if [ -f "$textPath" ]; then displayText=$(cat "$textPath"); fi
    else
        if [ ! -f "$lockFile" ] && [ -n "$rawUrl" ]; then
            touch "$lockFile"
            (
                tempArt="$TMP_DIR/${trackHash}_temp_art.jpg"
                tempBlur="$TMP_DIR/${trackHash}_temp_blur.png"

                # Secure Python fetcher handles encoded file:// URIs (%20), http/https, and base64 payloads automatically
                python3 -c "
import urllib.request, urllib.parse, sys
try:
    url = sys.argv[1]
    if url.startswith('file://'):
        url = 'file://' + urllib.parse.unquote(url[7:])
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=8) as response, open(sys.argv[2], 'wb') as out_file:
        out_file.write(response.read())
except Exception as e:
    sys.exit(1)
" "$rawUrl" "$tempArt"

                if [ ! -s "$tempArt" ]; then
                    cp "$PLACEHOLDER" "$tempArt"
                fi

                echo "linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)" > "$colorPath"
                echo "#cdd6f4" > "$textPath"
                cp "$tempArt" "$blurPath"
                mv "$tempArt" "$finalArt"

                rm -f "$lockFile"
                (cd "$TMP_DIR" && ls -1t | tail -n +21 | xargs -r rm -f 2>/dev/null)

                dbus-send --session --type=signal /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Seeked int64:0 2>/dev/null
            ) </dev/null >/dev/null 2>&1 &

            ( sleep 0.1 && touch "$QS_RUN_WORKSPACES/workspaces.json" ) &
        fi
    fi

    # Retrieve length safely
    len_micro=$($PT metadata mpris:length 2>/dev/null)
    if [[ -n "$len_micro" && "$len_micro" =~ ^[0-9]+$ ]]; then
        len_sec=$((len_micro / 1000000))
    else
        len_sec=0
    fi
    if [ "$len_sec" -eq 0 ]; then len_sec=1; fi
    len_str=$(format_time "$len_sec")

    # Retrieve position securely using seconds float, ignoring microsecond regex failures
    if [ "$STATUS" = "Playing" ]; then
        pos_sec_float=$(LC_ALL=C $PT position 2>/dev/null)
        pos_sec=$(LC_ALL=C awk -v p="$pos_sec_float" 'BEGIN { printf "%.0f", p }' 2>/dev/null)
        
        if ! [[ "$pos_sec" =~ ^[0-9]+$ ]]; then
            if [ -f "$STATE_FILE" ]; then pos_sec=$(jq -r '.pos_sec' "$STATE_FILE" 2>/dev/null); else pos_sec=0; fi
        fi
        if [ -z "$pos_sec" ] || [ "$pos_sec" = "null" ]; then pos_sec=0; fi

        jq -n -c \
            --argjson pos_sec "$pos_sec" \
            --argjson len_sec "$len_sec" \
            '{pos_sec: $pos_sec, len_sec: $len_sec}' \
            > "$STATE_FILE"
    else
        pos_sec=0
        if [ -f "$STATE_FILE" ]; then
            saved_pos=$(jq -r '.pos_sec' "$STATE_FILE" 2>/dev/null)
            saved_len=$(jq -r '.len_sec' "$STATE_FILE" 2>/dev/null)
            if [ "$saved_len" = "$len_sec" ] && [ -n "$saved_pos" ] && [ "$saved_pos" != "null" ]; then
                pos_sec=$saved_pos
            fi
        fi
    fi

    percent=$((pos_sec * 100 / len_sec))
    pos_str=$(format_time "$pos_sec")
    time_str="${pos_str} / ${len_str}"

    player_raw=$($PT status -f "{{playerName}}" 2>/dev/null | head -n 1)
    player_nice="${player_raw^}"

    dev_icon="󰓃"; dev_name="Speaker"
    node_name=$(timeout 0.5 wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F'"' '/node\.name/ {print $2}')
    node_desc=$(timeout 0.5 wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F'"' '/node\.description/ {print $2}')

    if [[ "$node_name" == *"bluez"* ]]; then
        dev_icon="󰂯"
        [ -n "$node_desc" ] && dev_name="$node_desc" || dev_name="Bluetooth"
    elif [[ "$node_name" == *"usb"* ]]; then
        dev_icon="󰓃"; dev_name="USB Audio"
    elif [[ "$node_name" == *"pci"* ]]; then
        dev_icon="󰓃"; dev_name="System"
    elif [ -n "$node_desc" ]; then
        dev_name="$node_desc"
    fi

    finalArtUrl="${displayArt}"

    jq -n -c \
        --arg title "$title" \
        --arg artist "$artist" \
        --arg status "$STATUS" \
        --arg len "$len_sec" \
        --arg pos "$pos_sec" \
        --arg len_str "$len_str" \
        --arg pos_str "$pos_str" \
        --arg time_str "$time_str" \
        --arg percent "$percent" \
        --arg source "$player_nice" \
        --arg pname "$player_raw" \
        --arg blur "$displayBlur" \
        --arg grad "$displayGrad" \
        --arg txtColor "$displayText" \
        --arg devIcon "$dev_icon" \
        --arg devName "$dev_name" \
        --arg finalArt "$finalArtUrl" \
        '{
            title: $title,
            artist: $artist,
            status: $status,
            length: $len,
            position: $pos,
            lengthStr: $len_str,
            positionStr: $pos_str,
            timeStr: $time_str,
            percent: $percent,
            source: $source,
            playerName: $pname,
            blur: $blur,
            grad: $grad,
            textColor: $txtColor,
            deviceIcon: $devIcon,
            deviceName: $devName,
            artUrl: $finalArt
        }'

else
    if [ -f "$STATE_FILE" ]; then
        last_pos_sec=$(jq -r '.pos_sec' "$STATE_FILE" 2>/dev/null)
        last_len_sec=$(jq -r '.len_sec' "$STATE_FILE" 2>/dev/null)
    else
        last_pos_sec=0; last_len_sec=0
    fi

    if [ -z "$last_pos_sec" ] || [ "$last_pos_sec" = "null" ]; then last_pos_sec=0; fi
    if [ -z "$last_len_sec" ] || [ "$last_len_sec" = "null" ] || [ "$last_len_sec" -eq 0 ]; then last_len_sec=1; fi

    last_percent=$((last_pos_sec * 100 / last_len_sec))
    last_pos_str=$(format_time "$last_pos_sec")
    last_len_str=$(format_time "$last_len_sec")
    last_time_str="${last_pos_str} / ${last_len_str}"

    finalArtUrl="${PLACEHOLDER}"

    jq -n -c \
    --arg placeholder "$finalArtUrl" \
    --arg pos_str "$last_pos_str" \
    --arg len_str "$last_len_str" \
    --arg time_str "$last_time_str" \
    --arg percent "$last_percent" \
    '{
        title: "Not Playing",
        artist: "",
        status: "Stopped",
        percent: $percent,
        lengthStr: $len_str,
        positionStr: $pos_str,
        timeStr: $time_str,
        source: "Offline",
        playerName: "",
        blur: $placeholder,
        grad: "linear-gradient(45deg, #cba6f7, #89b4fa, #f38ba8, #cba6f7)",
        textColor: "#cdd6f4",
        deviceIcon: "󰓃",
        deviceName: "Speaker",
        artUrl: $placeholder
    }'
fi