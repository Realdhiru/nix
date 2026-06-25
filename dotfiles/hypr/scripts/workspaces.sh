#!/usr/bin/env bash

# Initialize caching directory via quickshell hooks
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "workspaces"

# Trim down from 69 to a standard layout maximum to minimize jq iteration overhead
SEQ_END=10

# De-duplicate historical runtime thread pools to prevent process leaking
for pid in $(pgrep -f "workspaces.sh"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

cleanup() { pkill -P $$ 2>/dev/null; }
trap cleanup EXIT SIGTERM SIGINT

print_workspaces() {
    # Atomic retrieval of both workspaces and active workspace layout in one execution pass
    raw_spaces=$(hyprctl workspaces -j 2>/dev/null)
    raw_active=$(hyprctl activeworkspace -j 2>/dev/null)

    if [ -z "$raw_spaces" ] || [ -z "$raw_active" ]; then return; fi

    active=$(echo "$raw_active" | jq '.id')

    # Fast map transformation directly matching active and occupied indices
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

initial synchronization checkpoint run
print_workspaces

handle_event_stream() {
    # Listen to raw stream without clearing or dropping adjacent thread frames
    socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - 2>/dev/null | while read -r line; do
        case "$line" in
            workspace*|focusedmon*|activewindow*|createwindow*|closewindow*|movewindow*|destroyworkspace*)
                print_workspaces
                ;;
        esac
    done
}

while true; do
    handle_event_stream
    sleep 0.2
done