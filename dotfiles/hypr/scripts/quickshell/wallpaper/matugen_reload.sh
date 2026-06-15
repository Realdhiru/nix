#!/usr/bin/env bash

# Reload Cava
if pgrep -x cava >/dev/null; then
    cat ~/.config/cava/config_base ~/.config/cava/colors > ~/.config/cava/config
    pkill -USR1 cava
fi

# Reload Quickshell
pkill quickshell
quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml &