#!/usr/bin/env bash
set -euo pipefail

systemctl --user stop graphical-session.target graphical-session-pre.target || true

sleep 0.5

hyprctl dispatch exit || pkill -u "$(id -u)" -x Hyprland