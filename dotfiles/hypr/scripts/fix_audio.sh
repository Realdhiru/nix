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

    # Ensure physical sinks and ALSA hardware switches are unmuted
    for nid in $(pw-cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "alsa_output.*"/ {gsub(/,/, "", id); print id}'); do
        wpctl set-mute "$nid" 0 2>/dev/null || true
    done
    if command -v amixer >/dev/null 2>&1; then
        amixer -c 0 sset Master unmute >/dev/null 2>&1 || true
        amixer -c 0 sset Headphone unmute >/dev/null 2>&1 || true
        amixer -c 0 sset Speaker unmute >/dev/null 2>&1 || true
        amixer -c 0 sset 'Auto-Mute Mode' Disabled >/dev/null 2>&1 || true
    fi

    # Notify user
    notify-send -a "Audio" "Audio Graph Refreshed" 2>/dev/null || true
else
    # Core daemon dead/hung: full service restart
    systemctl --user restart pipewire pipewire-pulse wireplumber
    sleep 1
    "$HOME/nix/dotfiles/hypr/scripts/quickshell/music/equalizer.sh" --init 2>/dev/null || true
    "$HOME/nix/dotfiles/hypr/scripts/qs_manager.sh" reload 2>/dev/null || true
    for _ in {1..20}; do
        if busctl --user status org.freedesktop.Notifications >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
    notify-send -a "Audio" "Audio Stack Restarted" 2>/dev/null || true
fi