#!/usr/bin/env bash
# Compatibility shim delegating to decoupled wallpaper subsystem
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_CLI="$HOME/.config/wallpaper/wallpaper.sh"
[ ! -x "$WALLPAPER_CLI" ] && WALLPAPER_CLI="$SCRIPT_DIR/../../wallpaper/wallpaper.sh"
exec "$WALLPAPER_CLI" boot "$@"
