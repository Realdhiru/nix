#!/usr/bin/env bash
set -uo pipefail

QUERY="${1:-}"
MODE="${2:-auto}"
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

echo "=== Starting search for: '$QUERY' (mode: $MODE) ===" > "$LOG_FILE"
mkdir -p "$SEARCH_DIR" "$(dirname "$CONTROL_FILE")"

# Normalize query
QUERY=$(echo "$QUERY" | tr '_-' ' ' | xargs 2>/dev/null || echo "$QUERY")
lower_q=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

# Detect if query or mode requests animated / video content
WANTS_ANIMATION=0
if [ "$MODE" = "gif" ] || [ "$MODE" = "video" ]; then
    WANTS_ANIMATION=1
elif [ "$MODE" = "auto" ] && [[ "$lower_q" =~ (gif|gifs|video|videos|mp4|animated|animation|loop) ]]; then
    WANTS_ANIMATION=1
fi

check_control() {
    local state
    state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:space:]')
    if [ "$state" = "stop" ]; then
        echo "Stop signal received. Exiting." >> "$LOG_FILE"
        exit 0
    fi
    while [ "$state" = "pause" ]; do
        sleep 1
        state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:space:]')
        [ "$state" = "stop" ] && exit 0
    done
}

# -----------------------------------------------------------------------------
# 1. Giphy Animation / Video Search (activated when mode is gif/video or auto query asks for it)
# -----------------------------------------------------------------------------
if [ "$WANTS_ANIMATION" -eq 1 ]; then
    check_control
    clean_giphy_q=$(echo "$lower_q" | sed -E 's/(gif|gifs|video|videos|mp4|animated|animation|loop)//g' | xargs 2>/dev/null || echo "")
    [ -z "$clean_giphy_q" ] && clean_giphy_q="wallpaper aesthetic loop"
    giphy_slug=$(echo "$clean_giphy_q" | tr ' ' '-')

    echo "Querying Giphy for animated content: $giphy_slug" >> "$LOG_FILE"
    giphy_html=$(curl -s -m 8 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        "https://giphy.com/search/${giphy_slug}" 2>/dev/null || true)

    mapfile -t giphy_gif_urls < <(echo "$giphy_html" | grep -o 'https://media[0-9]*\.giphy\.com/media/[^" ]*/giphy\.gif' | sort -u | head -n 24)

    if [ "${#giphy_gif_urls[@]}" -gt 0 ]; then
        curl_args=()
        batch_entries=()
        for gif_url in "${giphy_gif_urls[@]}"; do
            uuid=$(date +%s%N)
            thumb_url=$(echo "$gif_url" | sed -E 's|/giphy\.gif$|/200.gif|')
            full_url="$gif_url"

            # If user explicitly asked for video, deliver high-efficiency MP4 video wallpaper
            if [ "$MODE" = "video" ] || { [ "$MODE" = "auto" ] && [[ "$lower_q" =~ (video|videos|mp4) ]]; }; then
                full_url=$(echo "$gif_url" | sed -E 's|\.gif$|.mp4|')
            fi

            filename="ddg_${uuid}.gif"
            filepath="$SEARCH_DIR/$filename"
            tmppath="${filepath}.tmp"

            curl_args+=( "$thumb_url" -o "$tmppath" )
            batch_entries+=( "$tmppath|$filepath|$filename|$full_url" )
        done

        if [ "${#curl_args[@]}" -gt 0 ]; then
            echo "Downloading ${#curl_args[@]} Giphy thumbnails in parallel..." >> "$LOG_FILE"
            curl -Z -s -L -m 8 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "${curl_args[@]}" || true

            check_control
            for entry in "${batch_entries[@]}"; do
                IFS='|' read -r tmp fp fn fu <<< "$entry"
                if [ -s "$tmp" ]; then
                    mv "$tmp" "$fp"
                    echo "$fn|$fu" >> "$MAP_FILE"
                else
                    rm -f "$tmp"
                fi
            done
            echo "Giphy batch complete." >> "$LOG_FILE"
        fi
    fi

    # If user explicitly requested gif or video, finish here without mixing photos
    if [ "$MODE" = "gif" ] || [ "$MODE" = "video" ]; then
        echo 'done' > "$CONTROL_FILE"
        echo "=== Pipeline finished (mode: $MODE) ===" >> "$LOG_FILE"
        exit 0
    fi
fi

# -----------------------------------------------------------------------------
# 2. Wallhaven Curated High-Resolution Imagery (Favorites / Top Rated)
# -----------------------------------------------------------------------------
encoded_q=$(jq -rn --arg q "$QUERY" '$q|@uri')

for page in 1 2; do
    check_control

    if [ -z "$QUERY" ]; then
        url="https://wallhaven.cc/api/v1/search?sorting=toplist&topRange=1M&order=desc&categories=111&purity=100&ratios=16x9,16x10,landscape&atleast=1920x1080&page=${page}"
    else
        # sorting=favorites returns the highest quality, most acclaimed wallpapers matching the query
        url="https://wallhaven.cc/api/v1/search?q=${encoded_q}&categories=111&purity=100&sorting=favorites&order=desc&ratios=16x9,16x10,landscape&atleast=1920x1080&page=${page}"
    fi

    echo "Querying Wallhaven page $page: $url" >> "$LOG_FILE"
    res=$(curl -s -m 8 -A "Mozilla/5.0 (X11; Linux x86_64)" "$url" 2>/dev/null || true)
    count=$(echo "$res" | jq -r '.data | length' 2>/dev/null || echo "0")

    # Fallback: if strict ratio filter returned 0, search across all ratios with favorites
    if [ "$count" -eq 0 ] && [ "$page" -eq 1 ] && [ -n "$QUERY" ]; then
        url="https://wallhaven.cc/api/v1/search?q=${encoded_q}&categories=111&purity=100&sorting=favorites&order=desc&page=1"
        res=$(curl -s -m 8 -A "Mozilla/5.0 (X11; Linux x86_64)" "$url" 2>/dev/null || true)
        count=$(echo "$res" | jq -r '.data | length' 2>/dev/null || echo "0")
    fi

    [ "$count" -eq 0 ] && break

    curl_args=()
    batch_entries=()
    while IFS='|' read -r thumb_url full_url; do
        [ -z "$thumb_url" ] || [ -z "$full_url" ] && continue

        uuid=$(date +%s%N)
        thumb_ext="${thumb_url##*.}"
        thumb_ext="${thumb_ext%%\?*}"
        thumb_ext=$(echo "$thumb_ext" | tr '[:upper:]' '[:lower:]')
        [[ ! "$thumb_ext" =~ ^(jpg|jpeg|png|webp|gif)$ ]] && thumb_ext="jpg"

        filename="ddg_${uuid}.${thumb_ext}"
        filepath="$SEARCH_DIR/$filename"
        tmppath="${filepath}.tmp"

        curl_args+=( "$thumb_url" -o "$tmppath" )
        batch_entries+=( "$tmppath|$filepath|$filename|$full_url" )
    done < <(echo "$res" | jq -r '.data[]? | "\(.thumbs.large // .thumbs.original // .thumbs.small)|\(.path)"' 2>/dev/null || true)

    if [ "${#curl_args[@]}" -gt 0 ]; then
        echo "Downloading ${#curl_args[@]} Wallhaven thumbnails in parallel for page $page" >> "$LOG_FILE"
        curl -Z -s -L -m 8 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "${curl_args[@]}" || true

        check_control

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

# -----------------------------------------------------------------------------
# 3. Multi-Source Public Domain / Web Repository (Wikimedia Commons >= FHD)
# -----------------------------------------------------------------------------
if [ -n "$QUERY" ]; then
    check_control
    wm_url="https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=${encoded_q}+wallpaper+filetype:bitmap&gsrnamespace=6&gsrlimit=12&prop=imageinfo&iiprop=url|size&iiurlwidth=960&format=json"
    echo "Querying Wikimedia Commons: $wm_url" >> "$LOG_FILE"
    wm_res=$(curl -s -m 8 -A "WallpaperPickerRice/1.0" "$wm_url" 2>/dev/null || true)

    curl_args=()
    batch_entries=()
    while IFS='|' read -r thumb_url full_url; do
        [ -z "$thumb_url" ] || [ -z "$full_url" ] && continue

        uuid=$(date +%s%N)
        filename="ddg_${uuid}.jpg"
        filepath="$SEARCH_DIR/$filename"
        tmppath="${filepath}.tmp"

        curl_args+=( "$thumb_url" -o "$tmppath" )
        batch_entries+=( "$tmppath|$filepath|$filename|$full_url" )
    done < <(echo "$wm_res" | jq -r '.query.pages[]? | select(.imageinfo[0].width >= 1920) | "\(.imageinfo[0].thumburl)|\(.imageinfo[0].url)"' 2>/dev/null || true)

    if [ "${#curl_args[@]}" -gt 0 ]; then
        echo "Downloading ${#curl_args[@]} Wikimedia thumbnails in parallel..." >> "$LOG_FILE"
        curl -Z -s -L -m 8 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "${curl_args[@]}" || true

        check_control
        for entry in "${batch_entries[@]}"; do
            IFS='|' read -r tmp fp fn fu <<< "$entry"
            if [ -s "$tmp" ]; then
                mv "$tmp" "$fp"
                echo "$fn|$fu" >> "$MAP_FILE"
            else
                rm -f "$tmp"
            fi
        done
        echo "Wikimedia batch complete." >> "$LOG_FILE"
    fi
fi

echo 'done' > "$CONTROL_FILE"
echo "=== Pipeline finished ===" >> "$LOG_FILE"
