#!/usr/bin/env bash

# Initialize caching directory via quickshell hooks
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "workspaces"

# Structural tracking ceiling definition
SEQ_END=69

# De-duplicate historical runtime thread pools to prevent process leaking
for pid in $(pgrep -f "workspaces.sh"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

# Signal binding trap to drop IPC child consumers instantly on thread closure
cleanup() { pkill -P $$ 2>/dev/null; }
trap cleanup EXIT SIGTERM SIGINT

print_workspaces() {
    # Extract structural compositor state streams cleanly
    spaces=$(timeout 2 hyprctl workspaces -j 2>/dev/null)
    active=$(timeout 2 hyprctl activeworkspace -j 2>/dev/null | jq '.id')

    # Guard clause to abort lookup map generation if IPC payload is corrupted
    if [ -z "$spaces" ] || [ -z "$active" ]; then return; fi

    # Perform atomic transformation mapping via unbuffered stream mapping
    echo "$spaces" | jq --unbuffered --argjson a "$active" --arg end "$SEQ_END" -c '
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

# Initial synchronization checkpoint run
print_workspaces

# Fast-path listener stream with microsecond execution dispatch handlers
handle_event_stream() {
    socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - 2>/dev/null | while read -r line; do
        case "$line" in
            workspace*|focusedmon*|activewindow*|createwindow*|closewindow*|movewindow*|destroyworkspace*)
                print_workspaces
                
                # Drain event storms instantly within a strict 5ms edge window
                while read -t 0.005 -r extra_line; do
                    continue
                done
                ;;
        esac
    done
}

# Persistent execution pipeline container
while true; do
    handle_event_stream
    sleep 0.05
done