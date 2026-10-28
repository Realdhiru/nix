#!/usr/bin/env bash
# Mode Controller (mode_ctl.sh)
# Single Source of Truth (SSOT) writer for modes.json
# Strictly follows order-independent state machine architecture.

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
    "coffee": false,
    "dnd": false
  },
  "computed": {
    "wallpaper": true,
    "blur": true,
    "shadow": true,
    "animations": true,
    "opacity_solid": false,
    "direct_scanout": 0,
    "tearing": 0,
    "idle_inhibit": false,
    "dnd": false
  }
}
EOF
    mv -f "$MODES_JSON.tmp.$$" "$MODES_JSON"
fi

recompute_and_apply() {
    local tmp_json="$MODES_JSON.tmp.$$"
    
    # Extract current computed values prior to recompute to avoid redundant subsystem work
    local old_wp="true" old_blur="true" old_shadow="true" old_anim="true" old_solid="false" old_direct="0" old_tearing="0" old_coffee="false" old_dnd="false"
    if [ -f "$MODES_JSON" ]; then
        read -r old_wp old_blur old_shadow old_anim old_solid old_direct old_tearing old_coffee old_dnd < <(
            jq -r '[
                .computed.wallpaper // true,
                .computed.blur // true,
                .computed.shadow // true,
                .computed.animations // true,
                .computed.opacity_solid // false,
                .computed.direct_scanout // 0,
                .computed.tearing // 0,
                .computed.idle_inhibit // false,
                .computed.dnd // false
            ] | @tsv' "$MODES_JSON" 2>/dev/null || echo "true true true true false 0 0 false false"
        )
    fi

    # Order-independent pure state calculation
    jq '
      .active as $a |
      ($a["wallpaper-kill"] // false) as $wp_kill |
      ($a["gaming"] // false) as $gaming |
      ($a["power-saver"] // false) as $saver |
      ($a["coffee"] // false) as $coffee |
      ($a["dnd"] // false) as $dnd |
      
      .computed = {
        "wallpaper": ((($wp_kill or $saver) | not)),
        "blur": ((($wp_kill or $gaming or $saver) | not)),
        "shadow": ((($wp_kill or $gaming or $saver) | not)),
        "animations": ((($gaming or $saver) | not)),
        "opacity_solid": ($wp_kill or $gaming or $saver),
        "direct_scanout": (if ($gaming or $saver) then 2 else 0 end),
        "tearing": (if $gaming then 1 else 0 end),
        "idle_inhibit": ($coffee == true),
        "dnd": ($dnd == true)
      }
    ' "$MODES_JSON" > "$tmp_json"

    if jq empty "$tmp_json" 2>/dev/null; then
        mv -f "$tmp_json" "$MODES_JSON"
    else
        rm -f "$tmp_json"
        return 1
    fi

    # Extract new computed values in a single pass
    local wp_val blur_val shadow_val anim_val solid_val direct_val tearing_val coffee_val dnd_val
    read -r wp_val blur_val shadow_val anim_val solid_val direct_val tearing_val coffee_val dnd_val < <(
        jq -r '[
            .computed.wallpaper,
            .computed.blur,
            .computed.shadow,
            .computed.animations,
            .computed.opacity_solid,
            .computed.direct_scanout,
            .computed.tearing,
            .computed.idle_inhibit,
            .computed.dnd
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
        bash "$state_ctl" modes "$is_game_active" "$is_wp_killed" "$coffee_val" "$dnd_val" 2>/dev/null || true
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

    set)
        MODE="${2:-}"
        TARGET_VAL="${3:-false}"
        [ -z "$MODE" ] && { echo "Usage: $0 set <mode> <true|false>"; exit 1; }
        [ "$TARGET_VAL" != "true" ] && TARGET_VAL="false"

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

        tmp_json="$MODES_JSON.tmp.$$"
        jq --arg m "$MODE" '.active[$m] = (if .active[$m] == true then false else true end)' "$MODES_JSON" > "$tmp_json"
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
        echo "Usage: $0 {get|is-active|set|toggle|apply|status} [mode] [value]"
        exit 1
        ;;
esac

flock -u 200
