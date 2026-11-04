#!/usr/bin/env bash
set -euo pipefail

# Clean recovery of PipeWire user-space audio stack without touching kernel modules
systemctl --user restart pipewire pipewire-pulse wireplumber

# Wait briefly for PipeWire daemon socket registration
sleep 1

# Re-initialize native equalizer pipeline to known-good baseline
"$HOME/nix/dotfiles/hypr/scripts/quickshell/music/equalizer.sh" --init 2>/dev/null || true

# Re-sync Quickshell widget state
"$HOME/nix/dotfiles/hypr/scripts/qs_manager.sh" reload 2>/dev/null || true

notify-send -a "Audio" -t 2000 -u low "Audio stack recovered" 2>/dev/null || true