#!/usr/bin/env bash
set -euo pipefail

user_systemctl() { timeout 15 systemctl --user "$@"; }
pw_cli() { timeout 5 pw-cli "$@"; }
wpctl() { timeout 5 env wpctl "$@"; }

# Require each daemon to be active; systemctl's multi-unit is-active succeeds
# when any listed unit is active, which can hide a broken part of the graph.
if pw_cli info 0 >/dev/null 2>&1 \
    && user_systemctl is-active --quiet pipewire.service \
    && user_systemctl is-active --quiet wireplumber.service \
    && user_systemctl is-active --quiet pipewire-pulse.service; then
    # Daemons are healthy: non-destructive graph and routing repair without dropping Bluetooth or PulseAudio sockets
    timeout 10 "${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/hypr/scripts/quickshell/music/equalizer.sh" --init 2>/dev/null || true
    
    # Enforce default sink routing to equalizer pipeline
    EQ_ID=$(pw_cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "effect_input.eq10"/ {gsub(/,/, "", id); print id}')
    if [ -n "$EQ_ID" ]; then
        wpctl set-default "$EQ_ID" 2>/dev/null || true
    fi

    # Ensure physical sinks and ALSA hardware switches are unmuted
    while IFS= read -r nid; do
        [ -n "$nid" ] || continue
        wpctl set-mute "$nid" 0 2>/dev/null || true
    done < <(pw_cli ls Node 2>/dev/null | awk '/id [0-9]+/ {id=$2} /node.name = "alsa_output.*"/ {gsub(/,/, "", id); print id}')
    if command -v amixer >/dev/null 2>&1; then
        timeout 3 env amixer -c 0 sset Master unmute >/dev/null 2>&1 || true
        timeout 3 env amixer -c 0 sset Headphone unmute >/dev/null 2>&1 || true
        timeout 3 env amixer -c 0 sset Speaker unmute >/dev/null 2>&1 || true
        timeout 3 env amixer -c 0 sset 'Auto-Mute Mode' Disabled >/dev/null 2>&1 || true
    fi

    # Notify user
    timeout 2 notify-send -a "Audio" "Audio Graph Refreshed" 2>/dev/null || true
else
    # Core daemon dead/hung: full service restart
    user_systemctl restart pipewire.service pipewire-pulse.service wireplumber.service
    timeout 10 "${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/hypr/scripts/quickshell/music/equalizer.sh" --init 2>/dev/null || true
    timeout 10 "${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/hypr/scripts/qs_manager.sh" reload 2>/dev/null || true
    timeout 2 notify-send -a "Audio" "Audio Stack Restarted" 2>/dev/null || true
fi
