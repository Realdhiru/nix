#!/usr/bin/env bash

# Initialize caching directory via quickshell hooks
source "$(dirname "${BASH_SOURCE[0]}")/caching.sh"
qs_ensure_cache "workspaces"

# Trimmed tracking ceiling to reduce jq iteration payload
SEQ_END=10

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
    # Removed the 'timeout 2' lock to allow native query resolution and prevent forced 2s stalling
    raw_spaces=$(hyprctl workspaces -j 2>/dev/null)
    raw_active=$(hyprctl activeworkspace -j 2>/dev/null)

    # Guard clause to abort lookup map generation if IPC payload is corrupted
    if [ -z "$raw_spaces" ] || [ -z "$raw_active" ]; then return; fi

    active_id=$(echo "$raw_active" | jq -r '.id')

    # Perform atomic transformation mapping via unbuffered stream
    echo "$raw_spaces" | jq --unbuffered --arg a "$active_id" --arg end "$SEQ_END" -c '
        (map( { (.id|tostring): . } ) | add) as $s |
        [range(1; ($end|tonumber) + 1)] | map(
            . as $i |
            (if ($i|tostring) == $a then "active"
             elif ($s[$i|tostring] != null and $s[$i|tostring].windows > 0) then "occupied"
             else "empty" end) as $state |
            (if $s[$i|tostring] != null then $s[$i|tostring].lastwindowtitle else "Empty" end) as $win |
            { id: $i, state: $state, tooltip: $win }
        )
    ' > "$QS_RUN_WORKSPACES/workspaces.tmp"
    
    mv "$QS_RUN_WORKSPACES/workspaces.tmp" "$QS_RUN_WORKSPACES/workspaces.json"
}

# Initial synchronization checkpoint
print_workspaces

# Fast-path listener stream with microsecond execution dispatch
handle_event_stream() {
    socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            workspace>>*|workspacev2>>*)
                raw="${line#*>>}"
                # Extracts the true integer ID securely whether the event contains a comma (v2) or not (v1)
                active_id="${raw%%,*}"
                
                # Instant visual update: Override JSON state locally without querying hyprctl
                jq --arg a "$active_id" -c 'map(
                    if (.id|tostring) == $a then .state = "active"
                    elif .state == "active" then .state = "occupied"
                    else . end
                )' "$QS_RUN_WORKSPACES/workspaces.json" > "$QS_RUN_WORKSPACES/workspaces.tmp" && mv "$QS_RUN_WORKSPACES/workspaces.tmp" "$QS_RUN_WORKSPACES/workspaces.json"
                ;;
            focusedmon>>*|focusedmonv2>>*)
                active_id="${line##*,}"
                
                jq --arg a "$active_id" -c 'map(
                    if (.id|tostring) == $a then .state = "active"
                    elif .state == "active" then .state = "occupied"
                    else . end
                )' "$QS_RUN_WORKSPACES/workspaces.json" > "$QS_RUN_WORKSPACES/workspaces.tmp" && mv "$QS_RUN_WORKSPACES/workspaces.tmp" "$QS_RUN_WORKSPACES/workspaces.json"
                ;;
            createworkspace*|destroyworkspace*|openwindow*|closewindow*|movewindow*|moveworkspace*|windowtitle*)
                # Structural window events: Debounce the buffer instantly before running the heavy query
                while read -t 0.005 -r extra_line; do continue; done
                print_workspaces
                ;;
        esac
    done
}

# Persistent execution pipeline container
while true; do
    handle_event_stream
    sleep 0.2
done