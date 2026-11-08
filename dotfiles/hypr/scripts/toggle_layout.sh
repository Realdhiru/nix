#!/usr/bin/env bash
# Fast atomic layout toggle between dwindle (tiling) and scrolling (Niri ribbon)
# Preserves and restores custom window proportions, splits, and layout memory across toggles.
set -euo pipefail

hyprctl() { timeout 3 env hyprctl "$@"; }

STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}/layout"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/current_layout.txt"
exec 9>"$STATE_DIR/layout.lock"
flock -w 5 9 || { echo "toggle_layout.sh: layout operation lock timed out" >&2; exit 1; }

cur=$(hyprctl getoption general:layout -j 2>/dev/null | jq -r '.str // "dwindle"')
if [ "$cur" = "scrolling" ]; then
    next="dwindle"
else
    next="scrolling"
fi

# 1. Snapshot active workspace tiled windows before switching
ws_json=$(hyprctl activeworkspace -j 2>/dev/null || echo "{}")
ws_id=$(echo "$ws_json" | jq -r '.id // empty')

count=0
if [ -n "$ws_id" ]; then
    clients_json=$(hyprctl clients -j 2>/dev/null || echo "[]")
    ws_windows=$(echo "$clients_json" | jq --argjson wsid "$ws_id" \
        '[.[] | select(.workspace.id == $wsid and .mapped == true and .floating == false and (.size[0] > 50))] | sort_by(.at[0])')
    count=$(echo "$ws_windows" | jq 'length')
    
    if [ "$count" -ge 1 ]; then
        echo "$ws_windows" > "$STATE_DIR/ws_${ws_id}_${cur}.json"
    fi
fi

# 2. Switch layout atomically
hyprctl eval "hl.config({ general = { layout = \"$next\" } })" >/dev/null 2>&1
echo "$next" > "$STATE_FILE.tmp" && mv -f "$STATE_FILE.tmp" "$STATE_FILE"

# 3. Restore layout state for target layout ($next)
if [ -n "$ws_id" ] && [ "$count" -ge 2 ]; then
    next_state="$STATE_DIR/ws_${ws_id}_${next}.json"
    cur_state="$STATE_DIR/ws_${ws_id}_${cur}.json"

    if [ "$count" -eq 2 ]; then
        # Query post-switch window layout on active workspace
        post_clients=$(hyprctl clients -j 2>/dev/null || echo "[]")
        post_wins=$(echo "$post_clients" | jq --argjson wsid "$ws_id" \
            '[.[] | select(.workspace.id == $wsid and .mapped == true and .floating == false and (.size[0] > 50))] | sort_by(.at[0])')
        
        left_addr=$(echo "$post_wins" | jq -r '.[0].address // empty')
        right_addr=$(echo "$post_wins" | jq -r '.[1].address // empty')
        cur_left_w=$(echo "$post_wins" | jq -r '.[0].size[0] // 683')

        if [ -n "$left_addr" ] && [ -n "$right_addr" ]; then
            target_left_w=""
            # Check if saved target state exists for this layout
            if [ -f "$next_state" ]; then
                target_left_w=$(jq -r --arg a "$left_addr" '.[] | select(.address == $a) | .size[0]' "$next_state" 2>/dev/null || true)
            fi

            # Fallback: preserve the size from the previous layout mode ($cur)
            if [ -z "$target_left_w" ] || [ "$target_left_w" = "null" ]; then
                if [ -f "$cur_state" ]; then
                    target_left_w=$(jq -r --arg a "$left_addr" '.[] | select(.address == $a) | .size[0]' "$cur_state" 2>/dev/null || true)
                fi
            fi

            if [ -n "$target_left_w" ] && [ "$target_left_w" != "null" ]; then
                delta=$(( target_left_w - cur_left_w ))
                if [ "$delta" -ne 0 ] && [ "$delta" -gt -450 ] && [ "$delta" -lt 450 ]; then
                    if [ "$next" = "dwindle" ]; then
                        hyprctl eval "hl.dispatch(hl.dsp.focus({ window = \"address:$left_addr\" })); hl.dispatch(hl.dsp.window.resize({ x = $delta, y = 0, relative = true }))" >/dev/null 2>&1
                    elif [ "$next" = "scrolling" ]; then
                        delta_frac=$(awk -v d="$delta" 'BEGIN { printf "%+0.02f", d / 1440 }')
                        inv_frac=$(awk -v d="$delta" 'BEGIN { printf "%+0.02f", -d / 1440 }')
                        hyprctl eval "hl.dispatch(hl.dsp.focus({ window = \"address:$left_addr\" })); hl.dispatch(hl.dsp.layout(\"colresize $delta_frac\")); hl.dispatch(hl.dsp.focus({ window = \"address:$right_addr\" })); hl.dispatch(hl.dsp.layout(\"colresize $inv_frac\")); hl.dispatch(hl.dsp.focus({ window = \"address:$left_addr\" }))" >/dev/null 2>&1
                    fi
                fi
            fi
        fi
    elif [ "$count" -ge 3 ]; then
        if [ "$next" = "scrolling" ]; then
            # If switching from Dwindle, check if any windows were vertically stacked (sharing X coordinate)
            mapfile -t addrs < <(echo "$ws_windows" | jq -r '.[].address')
            mapfile -t xs < <(echo "$ws_windows" | jq -r '.[].at[0]')
            for ((i = 1; i < ${#addrs[@]}; i++)); do
                prev_x=${xs[$((i-1))]}
                cur_x=${xs[$i]}
                diff=$(( cur_x - prev_x ))
                if [ "$diff" -ge -20 ] && [ "$diff" -le 20 ]; then
                    hyprctl eval "hl.dispatch(hl.dsp.focus({ window = \"address:${addrs[$((i-1))]}\" })); hl.dispatch(hl.dsp.layout(\"consume\"))" >/dev/null 2>&1
                fi
            done
        fi
    fi
fi

if [ "$next" = "scrolling" ]; then
    notify-send -a "Hyprland" "Layout: Scrolling"
else
    notify-send -a "Hyprland" "Layout: Dwindle"
fi
