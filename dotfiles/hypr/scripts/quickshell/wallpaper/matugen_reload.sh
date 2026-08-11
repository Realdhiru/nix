#!/usr/bin/env bash
#
# NOTE: DEAD CODE (documented 2026-08-11). Not reachable from any active
# path. The only reference was an unused RELOAD_SCRIPT export in
# WallpaperPicker.qml applyWallpaper(), which was removed because it was
# never invoked. It also hard-kills quickshell (pkill quickshell), so if it
# is ever wired up again it should use reload.sh-style qs management
# instead. Keep in sync if wallpaper/theme behavior changes.

# Reload Cava
if pgrep -x cava >/dev/null; then
    cat ~/.config/cava/config_base ~/.config/cava/colors > ~/.config/cava/config
    pkill -USR1 cava
fi

# Reload Quickshell
pkill quickshell
quickshell -p ~/.config/hypr/scripts/quickshell/Shell.qml &