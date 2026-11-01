#!/usr/bin/env bash
set -uo pipefail

QUERY="${1:-}"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Caching directory initialization
CACHE_DIR="${QS_CACHE_WALLPAPER_PICKER:-$HOME/.cache/quickshell/wallpaper_picker}"
SEARCH_DIR="$CACHE_DIR/search_thumbs"
MAP_FILE="$CACHE_DIR/search_map.txt"
CONTROL_FILE="${QS_RUN_WALLPAPER_PICKER:-$HOME/.cache/quickshell/run}/ddg_search_control"
LOG_FILE="${QS_LOG_DIR:-$HOME/.cache}/ddg_downloader.log"

if [ -f "$SCRIPT_DIR/../../caching.sh" ]; then
    source "$SCRIPT_DIR/../../caching.sh" 2>/dev/null || true
    [ "$(type -t qs_ensure_cache)" = "function" ] && qs_ensure_cache "wallpaper_picker"
fi

echo "=== Starting search for: $QUERY ===" > "$LOG_FILE"
mkdir -p "$SEARCH_DIR" "$(dirname "$CONTROL_FILE")"

# Normalize query
QUERY=$(echo "$QUERY" | tr '_-' ' ' | xargs 2>/dev/null || echo "$QUERY")
encoded_q=$(jq -rn --arg q "$QUERY" '$q|@uri')

for page in 1 2; do
    state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:space:]')
    [ "$state" = "stop" ] && { echo "Stop signal received. Exiting." >> "$LOG_FILE"; exit 0; }
    while [ "$state" = "pause" ]; do
        sleep 1
        state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:space:]')
    done

    if [ -z "$QUERY" ]; then
        url="https://wallhaven.cc/api/v1/search?sorting=toplist&order=desc&categories=111&purity=100&ratios=16x9,16x10,landscape&page=${page}"
    else
        url="https://wallhaven.cc/api/v1/search?q=${encoded_q}&categories=111&purity=100&sorting=relevance&order=desc&ratios=16x9,16x10,landscape&page=${page}"
    fi

    echo "Querying API page $page: $url" >> "$LOG_FILE"
    res=$(curl -s -m 8 -A "Mozilla/5.0 (X11; Linux x86_64)" "$url" 2>/dev/null || true)
    count=$(echo "$res" | jq -r '.data | length' 2>/dev/null || echo "0")
    if [ "$count" -eq 0 ] && [ "$page" -eq 1 ] && [ -n "$QUERY" ]; then
        url="https://wallhaven.cc/api/v1/search?q=${encoded_q}&categories=111&purity=100&sorting=relevance&order=desc&page=1"
        res=$(curl -s -m 8 -A "Mozilla/5.0 (X11; Linux x86_64)" "$url" 2>/dev/null || true)
        count=$(echo "$res" | jq -r '.data | length' 2>/dev/null || echo "0")
    fi

    [ "$count" -eq 0 ] && break

    curl_args=()
    batch_entries=()
    while IFS='|' read -r thumb_url full_url; do
        [ -z "$thumb_url" ] || [ -z "$full_url" ] && continue

        uuid=$(date +%s%N)
        ext="${full_url##*.}"
        ext="${ext%%\?*}"
        ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
        [[ ! "$ext" =~ ^(jpg|jpeg|png|webp|gif)$ ]] && ext="jpg"

        filename="ddg_${uuid}.${ext}"
        filepath="$SEARCH_DIR/$filename"
        tmppath="${filepath}.tmp"

        curl_args+=( "$thumb_url" -o "$tmppath" )
        batch_entries+=( "$tmppath|$filepath|$filename|$full_url" )
    done < <(echo "$res" | jq -r '.data[]? | "\(.thumbs.large // .thumbs.original // .thumbs.small)|\(.path)"' 2>/dev/null || true)

    if [ "${#curl_args[@]}" -gt 0 ]; then
        echo "Downloading ${#curl_args[@]} thumbnails in parallel for page $page" >> "$LOG_FILE"
        curl -Z -s -L -m 8 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "${curl_args[@]}" || true

        state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:space:]')
        if [ "$state" = "stop" ]; then
            for entry in "${batch_entries[@]}"; do
                IFS='|' read -r tmp _ _ _ <<< "$entry"
                rm -f "$tmp"
            done
            exit 0
        fi

        for entry in "${batch_entries[@]}"; do
            IFS='|' read -r tmp fp fn fu <<< "$entry"
            if [ -s "$tmp" ]; then
                mv "$tmp" "$fp"
                echo "$fn|$fu" >> "$MAP_FILE"
            else
                rm -f "$tmp"
            fi
        done
        echo "Page $page batch complete." >> "$LOG_FILE"
    fi
done

echo 'done' > "$CONTROL_FILE"
echo "=== Pipeline finished ===" >> "$LOG_FILE"