#!/usr/bin/env bash
# Fast, responsive wallpaper cycling with zero dropped clicks and zero queue backlog
set -euo pipefail

DIR="${1:-next}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
INDEX_FILE="$CACHE_DIR/quickshell/wallpaper_index.json"
PATHS_FILE="$CACHE_DIR/quickshell/wallpaper_paths.txt"
TARGET_TXT="$CACHE_DIR/target_wallpaper.txt"
DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
STATE_WALL_DIR="$DESKTOP_STATE_DIR/wallpaper"
STATE_QS_DIR="$DESKTOP_STATE_DIR/quickshell"
CURRENT_TXT="$STATE_WALL_DIR/current_wallpaper.txt"
FAV_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/wallpaper_favorites.txt"
STATE_JSON="$STATE_QS_DIR/state.json"
FILTER_TXT="$STATE_WALL_DIR/picker_filter.txt"

# Drop incoming repeat triggers while an application pass is in progress
CYCLE_LOCK="$CACHE_DIR/cycle_wallpaper.lock"
exec 9>"$CYCLE_LOCK"
if ! flock -n 9; then
    exit 0
fi


# Ensure pre-sorted paths cache exists and is fresh
if [ -f "$INDEX_FILE" ] && { [ ! -s "$PATHS_FILE" ] || [ "$INDEX_FILE" -nt "$PATHS_FILE" ]; }; then
    jq -r '
      def clean_name:
        if startswith("000_") then .[4:]
        elif (length > 33 and .[32:33] == "_") then .[33:]
        else . end;
      def type_rank:
        (.fileName | ascii_downcase) as $fn |
        if (.isVideo == true or ($fn | test("\\.(mp4|mkv|mov|webm)$"))) then 0
        elif ($fn | endswith(".gif")) then 1
        else 2 end;
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
# Only respect TARGET_TXT during active sub-second rapid cycling bursts
if [ -f "$TARGET_TXT" ] && [ -s "$TARGET_TXT" ]; then
    if [ -f "$CURRENT_TXT" ] && [ "$CURRENT_TXT" -nt "$TARGET_TXT" ]; then
        CUR_PATH="$(cat "$CURRENT_TXT" 2>/dev/null | tr -d '\r\n')"
        rm -f "$TARGET_TXT" 2>/dev/null || true
    else
        target_mtime=$(stat -c %Y "$TARGET_TXT" 2>/dev/null || echo 0)
        now_sec=$(date +%s)
        if [ $((now_sec - target_mtime)) -gt 2 ]; then
            [ -f "$CURRENT_TXT" ] && CUR_PATH="$(cat "$CURRENT_TXT" 2>/dev/null | tr -d '\r\n')"
            rm -f "$TARGET_TXT" 2>/dev/null || true
        else
            CUR_PATH="$(cat "$TARGET_TXT" 2>/dev/null | tr -d '\r\n')"
        fi
    fi
fi

if [ -z "$CUR_PATH" ] && [ -f "$CURRENT_TXT" ] && [ -s "$CURRENT_TXT" ]; then
    CUR_PATH="$(cat "$CURRENT_TXT" 2>/dev/null | tr -d '\r\n')"
fi
CUR_NAME="$(basename "$CUR_PATH" 2>/dev/null || echo "")"

# Read active filter from QuickShell state (SSOT)
FILTER="All"
if [ -f "$STATE_JSON" ]; then
    FILTER=$(jq -r '.ui.wallpaperFilter // "All"' "$STATE_JSON" 2>/dev/null || echo "All")
elif [ -f "$FILTER_TXT" ]; then
    FILTER=$(cat "$FILTER_TXT" 2>/dev/null || echo "All")
fi

CANDIDATES=""
if [[ "$FILTER" =~ ^(Favorites|Fav)$ ]] && [ -s "$FAV_FILE" ]; then
    CANDIDATES=$(awk 'NR==FNR { fav[$0]=1; next } fav[$0]' "$FAV_FILE" "$PATHS_FILE" 2>/dev/null || true)
elif [[ "$FILTER" =~ ^(GIFs|gif|GIF)$ ]]; then
    CANDIDATES=$(grep -i '\.gif$' "$PATHS_FILE" 2>/dev/null || true)
elif [[ "$FILTER" =~ ^(Videos|video|Vid)$ ]]; then
    CANDIDATES=$(grep -iE '\.(mp4|mkv|mov|webm)$' "$PATHS_FILE" 2>/dev/null || true)
elif [ "$FILTER" != "All" ] && [ "$FILTER" != "Search" ] && [ -n "$FILTER" ]; then
    FILTER_LOWER="${FILTER,,}"
    CANDIDATES=$(grep -i "/Wallpapers/${FILTER_LOWER}/" "$PATHS_FILE" 2>/dev/null || true)
fi

# Fallback to all paths if candidates list is empty
if [ -z "$CANDIDATES" ] && [ -s "$PATHS_FILE" ]; then
    CANDIDATES=$(cat "$PATHS_FILE" 2>/dev/null || true)
fi

TARGET_PATH=""
if [ -n "$CANDIDATES" ]; then
    TARGET_PATH=$(echo "$CANDIDATES" | awk -v cur="$CUR_PATH" -v cur_name="$CUR_NAME" -v dir="$DIR" '
        {
            paths[NR] = $0
            if ($0 == cur || (cur_name != "" && $0 ~ ("/" cur_name "$"))) {
                if (!cur_idx) cur_idx = NR
            }
        }
        END {
            total = NR
            if (total == 0) exit 1
            step = (dir == "prev" ? -1 : 1)
            if (!cur_idx) {
                next_idx = (step == 1 ? 1 : total)
            } else {
                next_idx = ((cur_idx - 1 + step + total) % total) + 1
            }
            print paths[next_idx]
        }
    ' 2>/dev/null || true)
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
        if (.isVideo == true or ($fn | test("\\.(mp4|mkv|mov|webm)$"))) then 0
        elif ($fn | endswith(".gif")) then 1
        else 2 end;


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
else
    notify-send -a "Wallpaper" -u low "No Wallpapers Found" 2>/dev/null || true
fi

flock -u 9 2>/dev/null || true
exec 9>&- 2>/dev/null || true
