#!/usr/bin/env bash
# Mode Controller (mode_ctl.sh)
# Single Source of Truth (SSOT) writer for modes.json
# Strictly follows order-independent state machine architecture with mode exclusivity.

set -euo pipefail

DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
MODES_DIR="$DESKTOP_STATE_DIR/modes"
MODES_JSON="$MODES_DIR/modes.json"
LOCK_FILE="$MODES_DIR/.modes.lock"

# IPC must never hold a compositor-driven caller indefinitely.
hyprctl() { timeout 3 env hyprctl "$@"; }

mkdir -p "$MODES_DIR"

acquire_lock() {
    exec 200>"$LOCK_FILE"
    flock -w 10 200
}

release_lock() {
    flock -u 200 2>/dev/null || true
    exec 200>&- 2>/dev/null || true
}

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

capture_baseline_if_clean() {
    local any_exclusive
    any_exclusive=$(jq -r '
        ((.active["wallpaper-kill"] // false) or
         (.active["gaming"] // false) or
         (.active["power-saver"] // false))
    ' "$MODES_JSON" 2>/dev/null || echo "false")

    if [ "$any_exclusive" = "false" ]; then
        local tmp="$MODES_JSON.tmp.$$"
        jq '.baseline = {
            "wallpaper": true,
            "blur": true,
            "shadow": true,
            "animations": true,
            "opacity_solid": false,
            "direct_scanout": 0,
            "tearing": 0
        }' "$MODES_JSON" > "$tmp" 2>/dev/null && mv -f "$tmp" "$MODES_JSON" || rm -f "$tmp"
    fi
}

recompute_and_apply() {
    local prior_saver="${1:-}"
    local prior_comp_json="${2:-}"
    local tmp_json="$MODES_JSON.tmp.$$"
    
    # Extract current computed values prior to recompute to avoid redundant subsystem work
    local old_wp="true" old_blur="true" old_shadow="true" old_anim="true" old_solid="false" old_direct="0" old_tearing="0" old_coffee="false" old_saver="false"
    if [ -n "$prior_comp_json" ] && [ "$prior_comp_json" != "{}" ]; then
        read -r old_wp old_blur old_shadow old_anim old_solid old_direct old_tearing old_coffee < <(
            echo "$prior_comp_json" | jq -r '[
                (if .wallpaper == null then true else .wallpaper end),
                (if .blur == null then true else .blur end),
                (if .shadow == null then true else .shadow end),
                (if .animations == null then true else .animations end),
                (if .opacity_solid == null then false else .opacity_solid end),
                (if .direct_scanout == null then 0 else .direct_scanout end),
                (if .tearing == null then 0 else .tearing end),
                (if .idle_inhibit == null then false else .idle_inhibit end)
            ] | @tsv' 2>/dev/null || echo "true true true true false 0 0 false"
        )
    elif [ -f "$MODES_JSON" ]; then
        read -r old_wp old_blur old_shadow old_anim old_solid old_direct old_tearing old_coffee old_saver < <(
            jq -r '[
                (if .computed.wallpaper == null then true else .computed.wallpaper end),
                (if .computed.blur == null then true else .computed.blur end),
                (if .computed.shadow == null then true else .computed.shadow end),
                (if .computed.animations == null then true else .computed.animations end),
                (if .computed.opacity_solid == null then false else .computed.opacity_solid end),
                (if .computed.direct_scanout == null then 0 else .computed.direct_scanout end),
                (if .computed.tearing == null then 0 else .computed.tearing end),
                (if .computed.idle_inhibit == null then false else .computed.idle_inhibit end),
                (if .active["power-saver"] == null then false else .active["power-saver"] end)
            ] | @tsv' "$MODES_JSON" 2>/dev/null || echo "true true true true false 0 0 false false"
        )
    fi
    [ -n "$prior_saver" ] && old_saver="$prior_saver"

    # Detect if an exclusive mode was active BEFORE this recompute and is now turning off.
    # When restoring from an exclusive mode, blur/shadow/anim restore to 'true' from baseline.
    local was_exclusive="false"
    { [ "$old_blur" = "false" ] || [ "$old_shadow" = "false" ] || [ "$old_anim" = "false" ]; } && was_exclusive="true"

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
    local wp_val blur_val shadow_val anim_val solid_val direct_val tearing_val coffee_val saver_val
    read -r wp_val blur_val shadow_val anim_val solid_val direct_val tearing_val coffee_val saver_val < <(
        jq -r '[
            .computed.wallpaper,
            .computed.blur,
            .computed.shadow,
            .computed.animations,
            .computed.opacity_solid,
            .computed.direct_scanout,
            .computed.tearing,
            .computed.idle_inhibit,
            (.active["power-saver"] // false)
        ] | @tsv' "$MODES_JSON"
    )

    # 1. Apply Compositor rules without reload.
    # Evaluates full blur/shadow configuration to guarantee exact appearance restoration.
    local restoring_exclusive="false"
    [ "$was_exclusive" = "true" ] && { [ "$blur_val" = "true" ] || [ "$shadow_val" = "true" ] || [ "$anim_val" = "true" ]; } && restoring_exclusive="true"

    if [ "$restoring_exclusive" = "true" ] || \
       [ "$blur_val" != "$old_blur" ] || [ "$shadow_val" != "$old_shadow" ] || \
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
            if [ "$blur_val" = "true" ]; then
                hyprctl eval "hl.config({
                    decoration = {
                        blur = { enabled = true, size = 8, passes = 1, vibrancy = 0.1696 },
                        shadow = { enabled = $shadow_val, range = 4, render_power = 3 }
                    },
                    animations = { enabled = $anim_val },
                    render = { direct_scanout = $direct_val },
                    misc = { vrr = $vrr_val },
                    general = { allow_tearing = $tearing_bool }
                })" >/dev/null 2>&1 || true
            else
                hyprctl eval "hl.config({
                    decoration = {
                        blur = { enabled = false },
                        shadow = { enabled = $shadow_val }
                    },
                    animations = { enabled = $anim_val },
                    render = { direct_scanout = $direct_val },
                    misc = { vrr = $vrr_val },
                    general = { allow_tearing = $tearing_bool }
                })" >/dev/null 2>&1 || true
            fi
        fi
    fi

    # 2. Wallpaper surface management only if wallpaper state changed
    if [ "$wp_val" != "$old_wp" ]; then
        if [ "$wp_val" = "false" ]; then
            # Preserve current wallpaper path in LAST_TXT before tearing down
            local cur_wp="$DESKTOP_STATE_DIR/wallpaper/current_wallpaper.txt"
            local last_wp="$DESKTOP_STATE_DIR/wallpaper/last_wallpaper.txt"
            if [ -s "$cur_wp" ]; then
                local prev_cur
                prev_cur="$(cat "$cur_wp" 2>/dev/null || true)"
                if [ -n "$prev_cur" ] && [ -f "$prev_cur" ]; then
                    local dir
                    dir="$(dirname "$last_wp")"
                    mkdir -p "$dir"
                    local tmp
                    tmp="$dir/.$(basename "$last_wp").tmp.$$"
                    printf '%s\n' "$prev_cur" > "$tmp"
                    mv -f "$tmp" "$last_wp"
                fi
            fi

            # Tear down both mpvpaper (video/GIF) and awww (static image) surfaces
            systemctl --user stop --no-block "mpvpaper@*" 2>/dev/null || true
            pkill -15 -f "mpvpaper" 2>/dev/null || true
            command -v awww >/dev/null 2>&1 && awww clear >/dev/null 2>&1 || true

            local theme_engine="${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/wallust/generate.sh"
            [ ! -x "$theme_engine" ] && theme_engine="${THEME_ENGINE:-$HOME/.config/wallust/generate.sh}"
            if [ -x "$theme_engine" ]; then
                "$theme_engine" --neutral >/dev/null 2>&1 || true
            fi
        else
            local target_wp="$DESKTOP_STATE_DIR/wallpaper/current_wallpaper.txt"
            [ ! -s "$target_wp" ] && target_wp="$DESKTOP_STATE_DIR/wallpaper/last_wallpaper.txt"
            if [ -s "$target_wp" ]; then
                local wp_path
                wp_path="$(cat "$target_wp" 2>/dev/null || true)"
                if [ -n "$wp_path" ] && [ -f "$wp_path" ]; then
                    local set_sh="${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/wallpaper/backend/set.sh"
                    [ ! -x "$set_sh" ] && set_sh="$HOME/.config/wallpaper/backend/set.sh"
                    if [ -x "$set_sh" ]; then
                        "$set_sh" "$wp_path" 200>&- >/dev/null 2>&1 || true
                    fi
                fi
            fi
        fi
    fi

    # 3. Window & terminal opacity update only if opacity_solid changed
    if [ "$solid_val" != "$old_solid" ]; then
        if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            local prop_val="unset"
            [ "$solid_val" = "true" ] && prop_val="1"
            hyprctl eval "
                for _, w in ipairs(hl.get_windows()) do
                    if w.address then
                        hl.dispatch(hl.dsp.window.set_prop({ window = 'address:' .. w.address, prop = 'opaque', value = '$prop_val' }))
                    end
                end
            " >/dev/null 2>&1 || true
        fi
        local term_op="${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/wallust/terminal-opacity.sh"
        [ ! -f "$term_op" ] && term_op="$HOME/.config/wallust/terminal-opacity.sh"
        if [ -f "$term_op" ]; then
            bash "$term_op" --reload >/dev/null 2>&1 || true
        fi
    fi

    # 4. Idle inhibition (coffee) only if coffee changed.
    # coffee-mode is NOT a pre-existing .service file — create a transient unit via systemd-run.
    if [ "$coffee_val" != "$old_coffee" ]; then
        if [ "$coffee_val" = "true" ]; then
            if ! systemctl --user is-active --quiet coffee-mode 2>/dev/null; then
                systemctl --user reset-failed coffee-mode 2>/dev/null || true
                systemd-run --user --unit=coffee-mode \
                    systemd-inhibit --what=idle:sleep --who=idle-inhibit-toggle \
                    --why="Coffee mode (idle inhibit)" --mode=block \
                    sleep infinity >/dev/null 2>&1 || true
            fi
        else
            systemctl --user stop coffee-mode 2>/dev/null || true
            systemctl --user reset-failed coffee-mode 2>/dev/null || true
        fi
    fi

    # 5. Synchronize hardware power profile when power-saver state changes
    if [ "${MODE_CTL_NO_PROFILE:-}" != "1" ]; then
        if [ "$old_saver" = "true" ] && [ "$saver_val" = "false" ]; then
            local target_prof="balanced"
            local ac_online="0"
            for ps in /sys/class/power_supply/*/online; do
                if [ -f "$ps" ] && [ "$(cat "$ps" 2>/dev/null || echo 0)" = "1" ]; then
                    ac_online="1"
                    break
                fi
            done
            [ "$ac_online" = "1" ] && target_prof="performance"

            local power_sh="$HOME/.config/hypr/scripts/power.sh"
            [ ! -x "$power_sh" ] && power_sh="${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/hypr/scripts/power.sh"
            if [ -x "$power_sh" ]; then
                CALLER_IS_MODE_CTL=true bash "$power_sh" profile "$target_prof" >/dev/null 2>&1 || {
                    echo "mode_ctl.sh: failed to synchronize hardware profile '$target_prof'" >&2
                    return 1
                }
            fi
        elif [ "$old_saver" = "false" ] && [ "$saver_val" = "true" ]; then
            local power_sh="$HOME/.config/hypr/scripts/power.sh"
            [ ! -x "$power_sh" ] && power_sh="${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/hypr/scripts/power.sh"
            if [ -x "$power_sh" ]; then
                CALLER_IS_MODE_CTL=true bash "$power_sh" profile power-saver >/dev/null 2>&1 || {
                    echo "mode_ctl.sh: failed to synchronize power-saver hardware profile" >&2
                    return 1
                }
            fi
        fi
    fi

    # 6. Backwards compatibility with state marker files & state.json
    local is_game_active="false"
    [ "$solid_val" = "true" ] && [ "$anim_val" = "false" ] && is_game_active="true"
    local is_wp_killed="false"
    [ "$wp_val" = "false" ] && is_wp_killed="true"

    if [ "$is_game_active" = "true" ]; then
        touch "$MODES_DIR/gaming_mode" 2>/dev/null || true
    else
        rm -f "$MODES_DIR/gaming_mode" 2>/dev/null || true
    fi

    if [ "$is_wp_killed" = "true" ]; then
        touch "$MODES_DIR/wallpaper_killed" 2>/dev/null || true
    else
        rm -f "$MODES_DIR/wallpaper_killed" 2>/dev/null || true
    fi

    local state_ctl="$HOME/.config/hypr/scripts/quickshell/state_ctl.sh"
    [ ! -x "$state_ctl" ] && state_ctl="${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/hypr/scripts/quickshell/state_ctl.sh"
    if [ -x "$state_ctl" ]; then
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
        # Always allow enabling via automatic preemption
        exit 0
        ;;

    set)
        acquire_lock
        MODE="${2:-}"
        TARGET_VAL="${3:-false}"
        [ -z "$MODE" ] && { echo "Usage: $0 set <mode> <true|false>"; release_lock; exit 1; }
        [ "$TARGET_VAL" != "true" ] && TARGET_VAL="false"

        capture_baseline_if_clean
        prior_saver=$(jq -r '.active["power-saver"] // false' "$MODES_JSON" 2>/dev/null || echo "false")
        prior_computed=$(jq -c '.computed // {}' "$MODES_JSON" 2>/dev/null || echo "{}")

        tmp_json="$MODES_JSON.tmp.$$"
        if [ "$TARGET_VAL" = "true" ]; then
            conflicts=$(get_conflicts "$MODE")
            # Atomically disable conflicting modes and enable the target mode in a single pass
            jq --arg m "$MODE" --arg c "$conflicts" '
                reduce ($c | split(" ") | .[]) as $conflict (.; if $conflict != "" then .active[$conflict] = false else . end) |
                .active[$m] = true
            ' "$MODES_JSON" > "$tmp_json"
        else
            jq --arg m "$MODE" '.active[$m] = false' "$MODES_JSON" > "$tmp_json"
        fi

        if jq empty "$tmp_json" 2>/dev/null; then
            mv -f "$tmp_json" "$MODES_JSON"
        else
            rm -f "$tmp_json"
            release_lock
            notify-send -a "System" -u critical "Failed"
            exit 1
        fi

        recompute_and_apply "$prior_saver" "$prior_computed"
        release_lock
        ;;

    toggle)
        acquire_lock
        MODE="${2:-}"
        [ -z "$MODE" ] && { echo "Usage: $0 toggle <mode>"; release_lock; exit 1; }

        current_val=$(jq -r --arg m "$MODE" '.active[$m] // false' "$MODES_JSON" 2>/dev/null || echo "false")
        if [ "$current_val" = "true" ]; then
            TARGET_VAL="false"
        else
            TARGET_VAL="true"
        fi

        capture_baseline_if_clean
        prior_saver=$(jq -r '.active["power-saver"] // false' "$MODES_JSON" 2>/dev/null || echo "false")
        prior_computed=$(jq -c '.computed // {}' "$MODES_JSON" 2>/dev/null || echo "{}")

        tmp_json="$MODES_JSON.tmp.$$"
        if [ "$TARGET_VAL" = "true" ]; then
            conflicts=$(get_conflicts "$MODE")
            jq --arg m "$MODE" --arg c "$conflicts" '
                reduce ($c | split(" ") | .[]) as $conflict (.; if $conflict != "" then .active[$conflict] = false else . end) |
                .active[$m] = true
            ' "$MODES_JSON" > "$tmp_json"
        else
            jq --arg m "$MODE" '.active[$m] = false' "$MODES_JSON" > "$tmp_json"
        fi

        if jq empty "$tmp_json" 2>/dev/null; then
            mv -f "$tmp_json" "$MODES_JSON"
        else
            rm -f "$tmp_json"
            release_lock
            notify-send -a "System" -u critical "Failed"
            exit 1
        fi

        recompute_and_apply "$prior_saver" "$prior_computed"
        new_val=$(jq -r --arg m "$MODE" '.active[$m]' "$MODES_JSON")
        release_lock
        if [ "$MODE" = "power-saver" ]; then
            if [ "$new_val" = "true" ]; then
                notify-send -a "Power" "Power-Saver ON" 2>/dev/null || true
            else
                notify-send -a "Power" "Power-Saver OFF" 2>/dev/null || true
            fi
        fi
        echo "$new_val"
        ;;

    apply)
        acquire_lock
        recompute_and_apply
        release_lock
        ;;

    status)
        cat "$MODES_JSON"
        ;;

    *)
        echo "Usage: $0 {get|is-active|can-enable|set|toggle|apply|status} [mode] [value]"
        exit 1
        ;;
esac
