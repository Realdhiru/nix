#!/usr/bin/env bash

# Initialize caching directory via quickshell hooks
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "workspaces"

SEQ_END=69

for pid in $(pgrep -f "workspaces.sh"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

cleanup() { pkill -P $$ 2>/dev/null; }
trap cleanup EXIT SIGTERM SIGINT

print_workspaces() {
    raw_spaces=$(hyprctl workspaces -j 2>/dev/null)
    raw_active=$(hyprctl activeworkspace -j 2>/dev/null)

    if [ -z "$raw_spaces" ] || [ -z "$raw_active" ]; then return; fi

    active=$(echo "$raw_active" | jq '.id')

    echo "$raw_spaces" | jq --unbuffered --argjson a "$active" --arg end "$SEQ_END" -c '
        (map( { (.id|tostring): . } ) | add) as $s |
        [range(1; ($end|tonumber) + 1)] | map(
            . as $i |
            (if $i == $a then "active"
             elif ($s[$i|tostring] != null and $s[$i|tostring].windows > 0) then "occupied"
             else "empty" end) as $state |
            (if $s[$i|tostring] != null then $s[$i|tostring].lastwindowtitle else "Empty" end) as $win |
            { id: $i, state: $state, tooltip: $win }
        )
    ' > "$QS_RUN_WORKSPACES/workspaces.tmp"
    
    mv "$QS_RUN_WORKSPACES/workspaces.tmp" "$QS_RUN_WORKSPACES/workspaces.json"
}

print_workspaces

handle_event_stream() {
    socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            workspace>>*)
                active_id="${line#*>>}"
                # Instant visual update: Override JSON state immediately in microseconds without querying hyprctl
                jq --arg a "$active_id" -c 'map(
                    if (.id|tostring) == $a then .state = "active"
                    elif .state == "active" then .state = "occupied"
                    else . end
                )' "$QS_RUN_WORKSPACES/workspaces.json" > "$QS_RUN_WORKSPACES/workspaces.tmp" && mv "$QS_RUN_WORKSPACES/workspaces.tmp" "$QS_RUN_WORKSPACES/workspaces.json"
                ;;
            focusedmon>>*)
                active_id="${line##*,}"
                jq --arg a "$active_id" -c 'map(
                    if (.id|tostring) == $a then .state = "active"
                    elif .state == "active" then .state = "occupied"
                    else . end
                )' "$QS_RUN_WORKSPACES/workspaces.json" > "$QS_RUN_WORKSPACES/workspaces.tmp" && mv "$QS_RUN_WORKSPACES/workspaces.tmp" "$QS_RUN_WORKSPACES/workspaces.json"
                ;;
            createworkspace*|destroyworkspace*|openwindow*|closewindow*|movewindow*|windowtitle*)
                print_workspaces
                ;;
        esac
    done
}

while true; do
    handle_event_stream
    sleep 0.2
done