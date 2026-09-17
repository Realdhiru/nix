#!/usr/bin/env bash
set -euo pipefail

# If fuzzel is already open, toggle it closed
if pkill -x fuzzel; then
    exit 0
fi

# If blur/transparency is disabled (in power-saver, gaming mode, or wallpaper killed),
# override background to 100% opaque solid charcoal (#111111ff) so text is razor sharp.
EXTRA_ARGS=()
CURRENT_PROFILE="$(cat "$HOME/.cache/qs_power_profile" 2>/dev/null || cat /tmp/qs_power_profile 2>/dev/null || echo "")"
if [ -f "$HOME/.cache/wallpaper_killed" ] || \
   [ -f "$HOME/.cache/gaming_mode" ] || \
   [ "$CURRENT_PROFILE" = "power-saver" ]; then
    EXTRA_ARGS+=(--background-color=111111ff)
fi

exec fuzzel "${EXTRA_ARGS[@]}"
