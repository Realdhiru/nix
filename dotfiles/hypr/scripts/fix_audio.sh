#!/usr/bin/env bash
set -euo pipefail

# Check if core daemons are responsive
if pw-cli info 0 >/dev/null 2>&1 && systemctl --user is-active --quiet pipewire wireplumber; then
    # Daemons are healthy: non-destructive graph and routing repair without dropping Bluetooth or PulseAudio sockets
    "$HOME/nix/dotfiles/hypr/scripts/quickshell/music/equalizer.sh" --init 2>/dev/null || true
    
    # Enforce default sink routing to equalizer pipeline
    EQ_ID=$(pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_input.eq10"/ {gsub(/,/, "", id); print id}')
    if [ -n "$EQ_ID" ]; then
        wpctl set-default "$EQ_ID" 2>/dev/null || true
    fi

    # Notify user
    notify-send -a "Audio" "Audio graph refreshed" 2>/dev/null || true

    # Re-sync Quickshell widget state
    "$HOME/nix/dotfiles/hypr/scripts/qs_manager.sh" reload 2>/dev/null || true
else
    # Core daemon dead/hung: full service restart
    systemctl --user restart pipewire pipewire-pulse wireplumber
    sleep 1
    "$HOME/nix/dotfiles/hypr/scripts/quickshell/music/equalizer.sh" --init 2>/dev/null || true
    notify-send -a "Audio" "Audio stack restarted" 2>/dev/null || true
    "$HOME/nix/dotfiles/hypr/scripts/qs_manager.sh" reload 2>/dev/null || true
fi