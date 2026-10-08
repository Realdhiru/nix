#!/usr/bin/env bash
# Ultra-fast cliphist fetcher utilizing native bash, jq, and parallel decoding
set -euo pipefail

OFFSET="${1:-0}"
LIMIT="${2:-12}"
CACHE_DIR="${3:-${QS_CACHE_CLIPBOARD:-$HOME/.cache/quickshell/clipboard}}"

mkdir -p "$CACHE_DIR"

# 1. Fetch slice from cliphist
mapfile -t ALL_LINES < <(cliphist list 2>/dev/null || true)

TOTAL=${#ALL_LINES[@]}
if [ "$TOTAL" -eq 0 ] || [ "$OFFSET" -ge "$TOTAL" ]; then
    echo "[]"
    exit 0
fi

# Background cache cleanup on initial page
if [ "$OFFSET" -eq 0 ]; then
    (
        declare -A VALID_IDS
        count=0
        for line in "${ALL_LINES[@]}"; do
            [ "$count" -ge 100 ] && break
            id="${line%%$'\t'*}"
            [ -n "$id" ] && VALID_IDS["$id"]=1
            ((count++))
        done

        for f in "$CACHE_DIR"/*.png; do
            [ -f "$f" ] || continue
            bn="$(basename "$f" .png)"
            if [[ -z "${VALID_IDS[$bn]:-}" ]]; then
                rm -f "$f" 2>/dev/null || true
            fi
        done
    ) >/dev/null 2>&1 &
fi

SLICE=("${ALL_LINES[@]:$OFFSET:$LIMIT}")

# 2. Parallel image decoding for binary entries
for line in "${SLICE[@]}"; do
    if [[ "$line" == *$'\t'*'[[ binary data'* ]]; then
        id="${line%%$'\t'*}"
        img_file="$CACHE_DIR/${id}.png"
        if [ ! -s "$img_file" ]; then
            cliphist decode "$id" > "$img_file" 2>/dev/null &
        fi
    fi
done
wait 2>/dev/null || true

# 3. Format JSON with jq
printf '%s\n' "${SLICE[@]}" | jq -R -s --arg cdir "$CACHE_DIR" '
  split("\n")
  | map(select(length > 0))
  | map(
      split("\t") as $parts
      | if ($parts | length) >= 2 then
          $parts[0] as $id
          | ($parts[1:] | join("\t")) as $content
          | if ($content | test("\\[\\[ binary data")) then
              { id: $id, content: ($cdir + "/" + $id + ".png"), type: "image" }
            else
              { id: $id, content: $content, type: "text" }
            end
        else
          empty
        end
    )
'
