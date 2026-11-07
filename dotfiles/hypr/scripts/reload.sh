#!/usr/bin/env bash

# Strict execution environment: Catch undefined variables and pipe failures
set -uo pipefail

# 1. Reload the compositor configuration.
if command -v hyprctl >/dev/null 2>&1; then
    timeout 5 hyprctl reload >/dev/null 2>&1 || exit 1
    # Re-apply persistent compositor flags from modes.json (single source of truth)
    MODES_CTL="${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/hypr/scripts/mode_ctl.sh"
    [ ! -x "$MODES_CTL" ] && MODES_CTL="$HOME/.config/hypr/scripts/mode_ctl.sh"
    [ -x "$MODES_CTL" ] && timeout 10 bash "$MODES_CTL" apply > /dev/null 2>&1 || exit 1
fi

# 2. One locked owner replaces the shell; startup and toggle use the same lock.
QS_MANAGER="${NIX_CONFIG_DIR:-$HOME/nix}/dotfiles/hypr/scripts/qs_manager.sh"
[ ! -x "$QS_MANAGER" ] && QS_MANAGER="$HOME/.config/hypr/scripts/qs_manager.sh"
bash "$QS_MANAGER" reload >/dev/null 2>&1 || exit 1

notify-send -a "System" "Reloaded" 2>/dev/null || true
