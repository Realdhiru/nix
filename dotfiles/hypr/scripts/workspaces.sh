#!/usr/bin/env bash

# Initialize caching directory via quickshell hooks
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "workspaces"

# Structural tracking ceiling definition (allows external override, defaults to 69)
SEQ_END=${SEQ_END:-69}

# Safe Singleton File Locking (Replaces dangerous pgrep/kill -9)
# Enforces a single writer without leaving orphaned socat instances
exec 200>"$QS_RUN_WORKSPACES/workspaces.lock"
if ! flock -n 200; then
    exit 0
fi

# Signal binding trap to drop IPC child consumers instantly on thread closure
cleanup() { pkill -P $$ 2>/dev/null; }
trap cleanup EXIT SIGTERM SIGINT

print_workspaces() {
    # Extract structural compositor state streams cleanly
    spaces=$(hyprctl workspaces -j 2>/dev/null)
    active=$(hyprctl activeworkspace -j 2>/dev/null | jq '.id')

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
    # Resurrection loop: Keeps the daemon alive if Hyprland restarts and drops the socket
    while true; do
        socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - 2>/dev/null | while read -r line; do
            case "$line" in
                workspace*|focusedmon*|activewindow*|createwindow*|closewindow*|movewindow*|destroyworkspace*)
                    # Debounce: Absorb and discard any subsequent events arriving within 50ms
                    # Prevents CPU thrashing and lag spikes during rapid window manipulations
                    while read -t 0.05 -r _; do continue; done
                    
                    print_workspaces
                    ;;
            esac
        done
        
        # Pause briefly before attempting to reconnect to a dead socket
        sleep 1
    done
}

# Execute persistent stream monitor
handle_event_stream