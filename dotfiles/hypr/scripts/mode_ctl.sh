#!/usr/bin/env bash
# Mode Controller (mode_ctl.sh)
# Single Source of Truth (SSOT) writer for modes.json
# Strictly follows order-independent state machine architecture with mode exclusivity.

set -euo pipefail

DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
MODES_DIR="$DESKTOP_STATE_DIR/modes"
MODES_JSON="$MODES_DIR/modes.json"
LOCK_FILE="$MODES_DIR/.modes.lock"

mkdir -p "$MODES_DIR"

exec 200>"$LOCK_FILE"
flock 200

rm -f "$MODES_DIR/gaming_mode" "$MODES_DIR/wallpaper_killed" "$MODES_DIR/saver_killed_wp" 2>/dev/null || true

# Initialize modes.json if absent or corrupted
if [ ! -s "$MODES_JSON" ] || ! jq empty "$MODES_JSON" 2>/dev/null; then
    cat << 'EOF' > "$MODES_JSON.tmp.$$"
{
  "active": {
    "wallpaper-kill": false,
    "gaming": false,
    "power-saver": false,
    "coffee": false
  },
  "baseline": {
    "wallpaper": true,
    "blur": true,
    "shadow": true,
    "animations": true,
    "opacity_solid": false,
    "direct_scanout": 0,
    "tearing": 0
  },
  "computed": {
    "wallpaper": true,
    "blur": true,
    "shadow": true,
    "animations": true,
    "opacity_solid": false,
    "direct_scanout": 0,
    "tearing": 0,
    "idle_inhibit": false
  }
}
EOF
    mv -f "$MODES_JSON.tmp.$$" "$MODES_JSON"
fi

# ==============================================================================
# Conflict Table (Exclusivity Matrix)
# power-saver conflicts with gaming and wallpaper-kill (and vice versa)
# coffee is completely independent.
# ==============================================================================
get_conflicts() {
    local target_mode="$1"
    case "$target_mode" in
        power-saver) echo "gaming wallpaper-kill" ;;
        gaming) echo "power-saver wallpaper-kill" ;;
        wallpaper-kill) echo "power-saver gaming" ;;
        *) echo "" ;;
    esac
}

check_conflict() {
    local target_mode="$1"
    local conflicts
    conflicts=$(get_conflicts "$target_mode")
    for c in $conflicts; do
        local is_on
        is_on=$(jq -r --arg c "$c" '.active[$c] // false' "$MODES_JSON" 2>/dev/null || echo "false")
        if [ "$is_on" = "true" ]; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

capture_baseline_if_clean() {
    local any_exclusive
    any_exclusive=$(jq -r '
        ((.active["wallpaper-kill"] // false) or
         (.active["gaming"] // false) or
         (.active["power-saver"] // false))
    ' "$MODES_JSON" 2>/dev/null || echo "false")

    if [ "$any_exclusive" = "false" ]; then
        if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            local b_blur b_shadow b_anim b_direct b_tear
            b_blur=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | jq -r '.bool // true')
            b_shadow=$(hyprctl getoption decoration:shadow:enabled -j 2>/dev/null | jq -r '.bool // true')
            b_anim=$(hyprctl getoption animations:enabled -j 2>/dev/null | jq -r '.bool // true')
            b_direct=$(hyprctl getoption render:direct_scanout -j 2>/dev/null | jq -r '.int // 0')
            b_tear=$(hyprctl getoption general:allow_tearing -j 2>/dev/null | jq -r '.bool // false')

            local tmp="$MODES_JSON.tmp.$$"
            jq --argjson blur "$b_blur" \
               --argjson shadow "$b_shadow" \
               --argjson anim "$b_anim" \
               --argjson direct "$b_direct" \
               --argjson tear "$b_tear" \
               '.baseline = {
                   "wallpaper": (.baseline.wallpaper // true),
                   "blur": $blur,
                   "shadow": $shadow,
                   "animations": $anim,
                   "opacity_solid": (.baseline.opacity_solid // false),
                   "direct_scanout": $direct,
                   "tearing": (if ($tear == true or $tear == 1) then 1 else 0 end)
               }' "$MODES_JSON" > "$tmp" 2>/dev/null && mv -f "$tmp" "$MODES_JSON" || rm -f "$tmp"
        fi
    fi
}

recompute_and_apply() {
    local tmp_json="$MODES_JSON.tmp.$$"
    
    # Extract current computed values prior to recompute to avoid redundant subsystem work
    local old_wp="true" old_blur="true" old_shadow="true" old_anim="true" old_solid="false" old_direct="0" old_tearing="0" old_coffee="false"
    if [ -f "$MODES_JSON" ]; then
        read -r old_wp old_blur old_shadow old_anim old_solid old_direct old_tearing old_coffee < <(
            jq -r '[
                .computed.wallpaper // true,
                .computed.blur // true,
                .computed.shadow // true,
                .computed.animations // true,
                .computed.opacity_solid // false,
                .computed.direct_scanout // 0,
                .computed.tearing // 0,
                .computed.idle_inhibit // false
            ] | @tsv' "$MODES_JSON" 2>/dev/null || echo "true true true true false 0 0 false"
        )
    fi

    # Pure state calculation preserving prior baseline when modes are disabled
    jq '
      .active as $a |
      ($a["wallpaper-kill"] // false) as $wp_kill |
      ($a["gaming"] // false) as $gaming |
      ($a["power-saver"] // false) as $saver |
      ($a["coffee"] // false) as $coffee |
      (.baseline // {}) as $b |
      
      .computed = {
        "wallpaper": (if ($wp_kill or $saver) then false else ($b.wallpaper // true) end),
        "blur": (if ($wp_kill or $gaming or $saver) then false else ($b.blur // true) end),
        "shadow": (if ($wp_kill or $gaming or $saver) then false else ($b.shadow // true) end),
        "animations": (if ($gaming or $saver) then false else ($b.animations // true) end),
        "opacity_solid": (if ($wp_kill or $gaming or $saver) then true else ($b.opacity_solid // false) end),
        "direct_scanout": (if ($gaming or $saver) then 2 else ($b.direct_scanout // 0) end),
        "tearing": (if $gaming then 1 else ($b.tearing // 0) end),
        "idle_inhibit": ($coffee == true)
      }
    ' "$MODES_JSON" > "$tmp_json"

    if jq empty "$tmp_json" 2>/dev/null; then
        mv -f "$tmp_json" "$MODES_JSON"
    else
        rm -f "$tmp_json"
        return 1
    fi

    # Extract new computed values in a single pass
    local wp_val blur_val shadow_val anim_val solid_val direct_val tearing_val coffee_val
    read -r wp_val blur_val shadow_val anim_val solid_val direct_val tearing_val coffee_val < <(
        jq -r '[
            .computed.wallpaper,
            .computed.blur,
            .computed.shadow,
            .computed.animations,
            .computed.opacity_solid,
            .computed.direct_scanout,
            .computed.tearing,
            .computed.idle_inhibit
        ] | @tsv' "$MODES_JSON"
    )

    # 1. Apply Compositor rules without reload only if compositor parameters changed
    if [ "$blur_val" != "$old_blur" ] || [ "$shadow_val" != "$old_shadow" ] || \
       [ "$anim_val" != "$old_anim" ] || [ "$direct_val" != "$old_direct" ] || \
       [ "$tearing_val" != "$old_tearing" ]; then
        local vrr_val=0
        local tearing_bool="false"
        if [ "$direct_val" -gt 0 ]; then
            vrr_val=1
        fi
        if [ "$tearing_val" -gt 0 ] || [ "$tearing_val" = "true" ]; then
            tearing_bool="true"
        fi

        if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            hyprctl eval "hl.config({
                decoration = { blur = { enabled = $blur_val }, shadow = { enabled = $shadow_val } },
                animations = { enabled = $anim_val },
                render = { direct_scanout = $direct_val },
                misc = { vrr = $vrr_val },
                general = { allow_tearing = $tearing_bool }
            })" >/dev/null 2>&1 || true
        fi
    fi

    # 2. Wallpaper surface management only if wallpaper state changed
    if [ "$wp_val" != "$old_wp" ]; then
        if [ "$wp_val" = "false" ]; then
            pkill -STOP -f "mpvpaper" 2>/dev/null || true
            command -v awww >/dev/null 2>&1 && awww clear >/dev/null 2>&1 || true
        else
            pkill -CONT -f "mpvpaper" 2>/dev/null || true
            local last_wp="$DESKTOP_STATE_DIR/wallpaper/current_wallpaper.txt"
            [ ! -s "$last_wp" ] && last_wp="$DESKTOP_STATE_DIR/wallpaper/last_wallpaper.txt"
            if [ -s "$last_wp" ]; then
                local wp_path
                wp_path="$(cat "$last_wp" 2>/dev/null || true)"
                if [ -n "$wp_path" ] && [ -f "$wp_path" ]; then
                    command -v awww >/dev/null 2>&1 && awww img "$wp_path" --filter Bilinear >/dev/null 2>&1 || true
                    local theme_engine="${THEME_ENGINE:-$HOME/.config/wallust/generate.sh}"
                    [ ! -x "$theme_engine" ] && theme_engine="$HOME/nix/dotfiles/wallust/generate.sh"
                    if [ -x "$theme_engine" ]; then
                        "$theme_engine" "$wp_path" >/dev/null 2>&1 &
                    fi
                fi
            fi
        fi
    fi

    # 3. Terminal opacity update only if opacity_solid changed
    if [ "$solid_val" != "$old_solid" ]; then
        local term_op="$HOME/nix/dotfiles/wallust/terminal-opacity.sh"
        [ -x "$term_op" ] && bash "$term_op" --reload >/dev/null 2>&1 || true
    fi

    # 4. Idle inhibition (coffee) only if coffee changed
    if [ "$coffee_val" != "$old_coffee" ]; then
        if [ "$coffee_val" = "true" ]; then
            systemctl --user start coffee-mode 2>/dev/null || true
        else
            systemctl --user stop coffee-mode 2>/dev/null || true
        fi
    fi

    # 5. Optional backwards compatibility with state.json (batched single atomic update)
    local state_ctl="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
    if [ -x "$state_ctl" ]; then
        local is_game_active="false"
        [ "$solid_val" = "true" ] && [ "$anim_val" = "false" ] && is_game_active="true"
        local is_wp_killed="false"
        [ "$wp_val" = "false" ] && is_wp_killed="true"
        bash "$state_ctl" modes "$is_game_active" "$is_wp_killed" "$coffee_val" 2>/dev/null || true
    fi
}

ACTION="${1:-status}"

case "$ACTION" in
    get)
        MODE="${2:-}"
        [ -z "$MODE" ] && { echo "false"; exit 0; }
        jq -r --arg m "$MODE" '.active[$m] // false' "$MODES_JSON"
        ;;

    is-active)
        MODE="${2:-}"
        [ -z "$MODE" ] && exit 1
        val=$(jq -r --arg m "$MODE" '.active[$m] // false' "$MODES_JSON")
        [ "$val" = "true" ] && exit 0 || exit 1
        ;;

    can-enable)
        MODE="${2:-}"
        [ -z "$MODE" ] && exit 1
        active_conflict=$(check_conflict "$MODE" || true)
        if [ -n "$active_conflict" ]; then
            notify-send -a "Mode" "${MODE} blocked: ${active_conflict} on"
            echo "${MODE} blocked: ${active_conflict} on" >&2
            exit 1
        fi
        exit 0
        ;;

    set)
        MODE="${2:-}"
        TARGET_VAL="${3:-false}"
        [ -z "$MODE" ] && { echo "Usage: $0 set <mode> <true|false>"; exit 1; }
        [ "$TARGET_VAL" != "true" ] && TARGET_VAL="false"

        if [ "$TARGET_VAL" = "true" ]; then
            active_conflict=$(check_conflict "$MODE" || true)
            if [ -n "$active_conflict" ]; then
                notify-send -a "Mode" "${MODE} blocked: ${active_conflict} on"
                echo "${MODE} blocked: ${active_conflict} on" >&2
                exit 0
            fi
            capture_baseline_if_clean
        fi

        tmp_json="$MODES_JSON.tmp.$$"
        jq --arg m "$MODE" --argjson v "$TARGET_VAL" '.active[$m] = $v' "$MODES_JSON" > "$tmp_json"
        if jq empty "$tmp_json" 2>/dev/null; then
            mv -f "$tmp_json" "$MODES_JSON"
        else
            rm -f "$tmp_json"
            exit 1
        fi

        recompute_and_apply
        ;;

    toggle)
        MODE="${2:-}"
        [ -z "$MODE" ] && { echo "Usage: $0 toggle <mode>"; exit 1; }

        current_val=$(jq -r --arg m "$MODE" '.active[$m] // false' "$MODES_JSON" 2>/dev/null || echo "false")
        if [ "$current_val" = "true" ]; then
            TARGET_VAL="false"
        else
            TARGET_VAL="true"
            active_conflict=$(check_conflict "$MODE" || true)
            if [ -n "$active_conflict" ]; then
                notify-send -a "Mode" "${MODE} blocked: ${active_conflict} on"
                echo "${MODE} blocked: ${active_conflict} on" >&2
                echo "false"
                exit 0
            fi
            capture_baseline_if_clean
        fi

        tmp_json="$MODES_JSON.tmp.$$"
        jq --arg m "$MODE" --argjson v "$TARGET_VAL" '.active[$m] = $v' "$MODES_JSON" > "$tmp_json"
        if jq empty "$tmp_json" 2>/dev/null; then
            mv -f "$tmp_json" "$MODES_JSON"
        else
            rm -f "$tmp_json"
            exit 1
        fi

        recompute_and_apply
        new_val=$(jq -r --arg m "$MODE" '.active[$m]' "$MODES_JSON")
        echo "$new_val"
        ;;

    apply)
        recompute_and_apply
        ;;

    status)
        cat "$MODES_JSON"
        ;;

    *)
        echo "Usage: $0 {get|is-active|can-enable|set|toggle|apply|status} [mode] [value]"
        exit 1
        ;;
esac

flock -u 200
