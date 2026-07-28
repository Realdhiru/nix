#!/usr/bin/env bash
set -x
# Generic per-game bubblewrap sandbox. Set as Lutris's "Command prefix"
# (Preferences -> System options, applies to ALL games; or per-game
# System options to opt individual games in/out). No editing needed when
# you add or remove games -- paths come from Lutris's own env vars.
#
# Per-game network toggle: in Lutris, per-game -> System options ->
# Environment variables -> add SANDBOX_ALLOW_NET=1 for games that need
# real network (multiplayer/login). Default is network OFF.
set -euo pipefail

# Lutris sets these for every game process it launches.
GAME_DIR="${GAMEDIR:-$PWD}"
PFX_DIR="${WINEPREFIX:-$HOME/Games/prefixes/default}"

mkdir -p "$PFX_DIR"

NET_ARGS=(--unshare-net)
if [ "${SANDBOX_ALLOW_NET:-0}" = "1" ]; then
    NET_ARGS=()
fi

exec bwrap \
    --die-with-parent \
    --unshare-pid \
    --unshare-ipc \
    --unshare-uts \
    "${NET_ARGS[@]}" \
    \
    --ro-bind /nix /nix \
    --ro-bind /run/current-system /run/current-system \
    --ro-bind /etc /etc \
    --ro-bind /usr /usr \
    --proc /proc \
    --dev-bind /dev/dri /dev/dri \
    --dev-bind /dev/input /dev/input \
    --tmpfs /dev/shm \
    \
    --bind "$XDG_RUNTIME_DIR/wayland-1" "$XDG_RUNTIME_DIR/wayland-1" \
    --bind "$XDG_RUNTIME_DIR/pipewire-0" "$XDG_RUNTIME_DIR/pipewire-0" \
    --bind "$XDG_RUNTIME_DIR/bus" "$XDG_RUNTIME_DIR/bus" \
    --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR" \
    --setenv WAYLAND_DISPLAY wayland-1 \
    --setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$XDG_RUNTIME_DIR/bus" \
    \
    --tmpfs "$HOME" \
    --ro-bind "$HOME/.local/share/Steam/compatibilitytools.d" "$HOME/.local/share/Steam/compatibilitytools.d" \
    --bind "$GAME_DIR" "$GAME_DIR" \
    --bind "$PFX_DIR" "$PFX_DIR" \
    \
    --chdir "$GAME_DIR" \
    --setenv HOME "$HOME" \
    --setenv WINEPREFIX "$PFX_DIR" \
    --setenv GAMEDIR "$GAME_DIR" \
    \
    "$@"
