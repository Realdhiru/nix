#!/usr/bin/env bash
# Fast, responsive wallpaper cycling with zero dropped clicks and zero queue backlog
set -euo pipefail

DIR="${1:-next}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CACHE_DIR="$HOME/.cache"
INDEX_FILE="$CACHE_DIR/quickshell/wallpaper_index.json"
PATHS_FILE="$CACHE_DIR/quickshell/wallpaper_paths.txt"
TARGET_TXT="$CACHE_DIR/target_wallpaper.txt"
CURRENT_TXT="$CACHE_DIR/current_wallpaper.txt"

# Drop incoming repeat triggers while an application pass is in progress
CYCLE_LOCK="$CACHE_DIR/cycle_wallpaper.lock"
exec 9>"$CYCLE_LOCK"
if ! flock -n 9; then
    exit 0
fi

# Enforce consistent 0.3s cadence across all wallpapers while holding the bind
TS_FILE="$CACHE_DIR/last_cycle_timestamp.txt"
INTERVAL_NS=300000000
NOW=$(date +%s%N)
if [ -f "$TS_FILE" ]; then
    LAST=$(cat "$TS_FILE" 2>/dev/null || echo 0)
    DIFF=$((NOW - LAST))
    if [ "$DIFF" -gt 0 ] && [ "$DIFF" -lt "$INTERVAL_NS" ]; then
        exit 0
    fi
fi
echo "$NOW" > "$TS_FILE"

# Ensure pre-sorted paths cache exists and is fresh
if [ -f "$INDEX_FILE" ] && { [ ! -s "$PATHS_FILE" ] || [ "$INDEX_FILE" -nt "$PATHS_FILE" ]; }; then
    jq -r '
      def clean_name:
        if startswith("000_") then .[4:]
        elif (length > 33 and .[32:33] == "_") then .[33:]
        else . end;
      def type_rank:
        (.fileName | ascii_downcase) as $fn |
        if ($fn | endswith(".gif")) then 1
        elif (.isVideo == true or ($fn | test("\\.(mp4|mkv|webm)$"))) then 2
        else 0 end;
      .items
      | sort_by(
          type_rank,
          -(.band // 0),
          (.colorKey // 0),
          (.fileName | clean_name | ascii_downcase)
        )
      | .[].filePath
    ' "$INDEX_FILE" > "$PATHS_FILE.tmp" 2>/dev/null && mv -f "$PATHS_FILE.tmp" "$PATHS_FILE" 2>/dev/null || true
fi

CUR_PATH=""
if [ -f "$TARGET_TXT" ] && [ -s "$TARGET_TXT" ]; then
    CUR_PATH="$(cat "$TARGET_TXT" 2>/dev/null | tr -d '\r\n')"
elif [ -f "$CURRENT_TXT" ] && [ -s "$CURRENT_TXT" ]; then
    CUR_PATH="$(cat "$CURRENT_TXT" 2>/dev/null | tr -d '\r\n')"
fi
CUR_NAME="$(basename "$CUR_PATH" 2>/dev/null || echo "")"

TARGET_PATH=""
if [ -s "$PATHS_FILE" ]; then
    TARGET_PATH=$(awk -v cur="$CUR_PATH" -v cur_name="$CUR_NAME" -v dir="$DIR" '
        {
            paths[NR] = $0
            if ($0 == cur || (cur_name != "" && $0 ~ ("/" cur_name "$"))) {
                if (!cur_idx) cur_idx = NR
            }
        }
        END {
            total = NR
            if (total == 0) exit 1
            if (!cur_idx) cur_idx = 1
            step = (dir == "prev" ? -1 : 1)
            next_idx = ((cur_idx - 1 + step + total) % total) + 1
            print paths[next_idx]
        }
    ' "$PATHS_FILE" 2>/dev/null || true)
fi

# Fallback to jq index if paths file is unavailable
if [ -z "$TARGET_PATH" ] && [ -f "$INDEX_FILE" ]; then
    TARGET_PATH=$(jq -r --arg cur_path "$CUR_PATH" --arg cur_name "$CUR_NAME" --arg dir "$DIR" '
      def clean_name:
        if startswith("000_") then .[4:]
        elif (length > 33 and .[32:33] == "_") then
          .[33:]
        else . end;
      def type_rank:
        (.fileName | ascii_downcase) as $fn |
        if ($fn | endswith(".gif")) then 1
        elif (.isVideo == true or ($fn | test("\\.(mp4|mkv|webm)$"))) then 2
        else 0 end;

      ($cur_name | clean_name | ascii_downcase) as $clean_cur_name |

      .items
      | sort_by(
          type_rank,
          -(.band // 0),
          (.colorKey // 0),
          (.fileName | clean_name | ascii_downcase)
        )
      | . as $sorted
      | ($sorted | length) as $len
      | if $len == 0 then empty else
          ([range($len)] | map(select(
            $sorted[.].filePath == $cur_path or
            ($sorted[.].fileName | clean_name | ascii_downcase) == $clean_cur_name
          ))[0] // 0) as $cur_idx
          | (if ($dir == "next" or $dir == "right" or $dir == "+1") then 1 else -1 end) as $step
          | (($cur_idx + $step + $len) % $len) as $next_idx
          | $sorted[$next_idx].filePath
        end
    ' "$INDEX_FILE" 2>/dev/null || true)
fi

if [ -n "$TARGET_PATH" ] && [ -f "$TARGET_PATH" ]; then
    echo "$TARGET_PATH" > "$TARGET_TXT" 2>/dev/null || true
    FORCE_CYCLE=1 "$SCRIPT_DIR/set_wallpaper.sh" "$TARGET_PATH" "none" "0.0" "120"
fi

flock -u 9 2>/dev/null || true
exec 9>&- 2>/dev/null || true
