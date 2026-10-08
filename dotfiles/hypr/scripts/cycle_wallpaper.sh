#!/usr/bin/env bash
# Cycle wallpaper left/right with hardware-accelerated awww transitions
set -euo pipefail

DIR="${1:-next}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CACHE_DIR="$HOME/.cache"
INDEX_FILE="$CACHE_DIR/quickshell/wallpaper_index.json"
TARGET_TXT="$CACHE_DIR/target_wallpaper.txt"
CURRENT_TXT="$CACHE_DIR/current_wallpaper.txt"

CUR_PATH=""
for cand in "$TARGET_TXT" "$CURRENT_TXT"; do
    if [ -f "$cand" ]; then
        c=$(cat "$cand" 2>/dev/null | tr -d "\r\n")
        if [ -n "$c" ]; then
            CUR_PATH="$c"
            break
        fi
    fi
done
CUR_NAME="$(basename "$CUR_PATH")"

TARGET_PATH=""
if [ -f "$INDEX_FILE" ]; then
    TARGET_PATH=$(jq -r --arg cur_path "$CUR_PATH" --arg cur_name "$CUR_NAME" --arg dir "$DIR" '
      def clean_name:
        if startswith("000_") then .[4:]
        elif (length > 33 and .[32:33] == "_") then
          .[33:]
        else . end;

      .items
      | sort_by(
          (if (.fileName | test("\\.gif$"; "i")) then 0
           elif .isVideo then 2
           else 1 end),
          -(.band // 1),
          (.colorKey // 0),
          (.fileName | clean_name | ascii_downcase)
        )
      | . as $sorted
      | ($sorted | length) as $len
      | if $len == 0 then empty else
          ([range($len)] | map(select($sorted[.].filePath == $cur_path or $sorted[.].fileName == $cur_name))[0] // 0) as $cur_idx
          | (if ($dir == "next" or $dir == "right" or $dir == "+1") then 1 else -1 end) as $step
          | (($cur_idx + $step + $len) % $len) as $next_idx
          | $sorted[$next_idx].filePath
        end
    ' "$INDEX_FILE" 2>/dev/null || true)
fi

if [ -n "$TARGET_PATH" ] && [ -f "$TARGET_PATH" ]; then
    echo "$TARGET_PATH" > "$TARGET_TXT" 2>/dev/null || true
    exec "$SCRIPT_DIR/set_wallpaper.sh" "$TARGET_PATH" "none" "0.0" "120"
fi
