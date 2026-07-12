#!/usr/bin/env bash
# Re-applies the last user-selected shader after Hyprland has dropped it.
#
# decoration:screen_shader is runtime-only state: it's set live via
# `hyprctl keyword` (see cycle-shader.sh) and is never written into any of
# the sourced hyprland .conf files. Any full Hyprland config reload
# therefore wipes it silently, with nothing in the static config to
# reapply it. Hyprland auto-reloads whenever a `source`d file changes on
# disk — this includes ~/.cache/hypr_power_monitor.conf, which
# BatteryPopup.qml's setPowerProfile() rewrites on every profile switch.
#
# This script is the shared restore path: cycle-shader.sh calls it when
# it finds the shader already empty (manual cycle case), and
# setPowerProfile() calls it after every profile switch (implicit-reload
# case). Both read/write the same $STATE_FILE cache so they stay in sync.
set -euo pipefail

STATE_FILE="$HOME/.cache/current_shader"

CURRENT_SHADER=$(hyprctl -j getoption decoration:screen_shader | jq -r '.str')

if [[ "$CURRENT_SHADER" == "[[EMPTY]]" || "$CURRENT_SHADER" == "null" || -z "$CURRENT_SHADER" ]]; then
    if [[ -f "$STATE_FILE" ]]; then
        LAST_SHADER=$(<"$STATE_FILE")

        if [[ -n "$LAST_SHADER" && "$LAST_SHADER" != "[[EMPTY]]" && -f "$LAST_SHADER" ]]; then
            hyprctl keyword decoration:screen_shader "$LAST_SHADER" >/dev/null
        fi
    fi
fi