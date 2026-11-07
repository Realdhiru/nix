#!/usr/bin/env bash
set -euo pipefail

hyprctl_bin="$(command -v hyprctl)"
jq_bin="$(command -v jq)"
flock_bin="$(command -v flock)"

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
exec 8>"$runtime_dir/desktop-monitor-refresh.lock"
"$flock_bin" -w 5 8 || { echo "refresh_monitor.sh: another refresh is still running" >&2; exit 1; }

monitors_json="$(timeout 3 "$hyprctl_bin" monitors all -j)"
monitor_json="$(jq -ec '([.[] | select((.disabled // false) != true and (.name | test("^(eDP|LVDS|DSI|MIPI)")))][0] // [.[] | select((.disabled // false) != true)][0]) // empty' <<< "$monitors_json")"
[ -n "$monitor_json" ] || exit 0

IFS=$'\t' read -r output_name description current_width current_height current_rate current_scale current_transform current_x current_y < <(
    "$jq_bin" -r '[.name, (.description // ""), .width, .height, .refreshRate, .scale, .transform, .x, .y] | @tsv' <<< "$monitor_json"
)
[ -n "$output_name" ] || exit 0

state_dir="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
intent_dir="$state_dir/monitors"
intent_file="$intent_dir/intent.json"
mkdir -p "$intent_dir"

display_key="$output_name"
[ -n "$description" ] && display_key="desc:$description"
saved_mode=""
saved_scale="$current_scale"
saved_transform="$current_transform"
if [ -s "$intent_file" ]; then
    IFS=$'\t' read -r saved_mode saved_scale saved_transform < <(
        "$jq_bin" -r --arg key "$display_key" --arg name "$output_name" \
            '[.displays[$key].mode // .displays[$name].mode // "", .displays[$key].scale // .displays[$name].scale // "", .displays[$key].transform // .displays[$name].transform // ""] | @tsv' \
            "$intent_file"
    )
    saved_scale="${saved_scale:-$current_scale}"
    saved_transform="${saved_transform:-$current_transform}"
fi
[[ "$saved_scale" =~ ^[0-9]+([.][0-9]+)?$ ]] || saved_scale="$current_scale"
[[ "$saved_transform" =~ ^[0-7]$ ]] || saved_transform="$current_transform"

width="$current_width"
height="$current_height"
if [[ "$saved_mode" =~ ^([0-9]+)x([0-9]+)@ ]]; then
    width="${BASH_REMATCH[1]}"
    height="${BASH_REMATCH[2]}"
fi

on_ac=0
has_battery=0
for type_path in /sys/class/power_supply/*/type; do
    [ -r "$type_path" ] || continue
    read -r supply_type < "$type_path"
    [ "$supply_type" = "Battery" ] && has_battery=1 && break
done
if [ "$has_battery" -eq 0 ]; then
    on_ac=1
else
    for online_path in /sys/class/power_supply/*/online; do
        [ -r "$online_path" ] || continue
        read -r online < "$online_path"
        [ "$online" = "1" ] && on_ac=1 && break
    done
fi

if [ "$on_ac" -eq 1 ]; then
    target_rate="${HYPR_REFRESH_AC:-120}"
else
    target_rate="${HYPR_REFRESH_BATTERY:-60}"
fi

target_mode="$(
    "$jq_bin" -r --argjson width "$width" --argjson height "$height" --argjson max_rate "$target_rate" '
        [.availableModes[]? | capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<rate>[0-9.]+)Hz$")
         | . + {w:(.w|tonumber), h:(.h|tonumber), rate:(.rate|tonumber)}
         | select(.w == $width and .h == $height)] as $modes
        | (([$modes[] | select(.rate <= $max_rate)] | if length == 0 then null else max_by(.rate) end)
           // (if ($modes | length) == 0 then null else ($modes | min_by(.rate)) end))
        | if . == null then empty else "\(.w)x\(.h)@\(.rate)" end
    ' <<< "$monitor_json"
)"
[ -n "$target_mode" ] || exit 0

target_rate_actual="${target_mode##*@}"
same_resolution=0
[[ "$current_width" == "$width" && "$current_height" == "$height" ]] && same_resolution=1
same_rate=0
awk -v current="$current_rate" -v target="$target_rate_actual" 'BEGIN { d=current-target; if (d<0) d=-d; exit(d<0.1 ? 0 : 1) }' && same_rate=1

# Resolve all monitor data before entering Hyprland's Lua IPC. Running another
# `hyprctl` from inside `hyprctl eval` can block the compositor on nested IPC.
if [ "$same_resolution" -ne 1 ] || [ "$same_rate" -ne 1 ]; then
    lua_quote() {
        local value="$1"
        value="${value//\\/\\\\}"
        value="${value//\'/\\\'}"
        printf "'%s'" "$value"
    }
    lua_output="$(lua_quote "$output_name")"
    lua_mode="$(lua_quote "$target_mode")"
    lua_position="$(lua_quote "${current_x}x${current_y}")"
    timeout 3 "$hyprctl_bin" eval "hl.monitor({output=$lua_output, mode=$lua_mode, position=$lua_position, scale=$saved_scale, transform=$saved_transform})"
fi

# Power policy owns refresh only; serialize the merge so monitor UI changes to
# layout, placement, scale, or transform survive a simultaneous power event.
exec 9>"$intent_file.lock"
"$flock_bin" -w 5 -x 9 || { echo "refresh_monitor.sh: monitor intent lock timed out" >&2; exit 1; }
tmp_file="$intent_file.tmp.$$"
if [ -s "$intent_file" ]; then
    "$jq_bin" --arg key "$display_key" --arg name "$output_name" --arg description "$description" \
        --arg mode "$target_mode" --argjson scale "$saved_scale" --argjson transform "$saved_transform" \
        '.layout = (.layout // "extend") | .displays = (.displays // {}) | ($key) as $k | .displays[$k] = ((.displays[$k] // {scale:$scale, transform:$transform}) + {name:$name, description:$description, mode:$mode})' \
        "$intent_file" > "$tmp_file"
else
    "$jq_bin" -n --arg key "$display_key" --arg name "$output_name" --arg description "$description" \
        --arg mode "$target_mode" --argjson scale "$saved_scale" --argjson transform "$saved_transform" \
        '{layout:"extend",displays:{($key):{name:$name,description:$description,mode:$mode,scale:$scale,transform:$transform}}}' > "$tmp_file"
fi
mv -f "$tmp_file" "$intent_file"
