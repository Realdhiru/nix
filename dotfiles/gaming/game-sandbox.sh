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
#
# ARCHITECTURE NOTE: this uses a DENYLIST model, not an allowlist. An
# earlier version hid all of $HOME and allowlisted individual paths
# (lutris, Steam compatibilitytools.d, umu) one at a time as each one
# broke -- Lutris/umu/Proton have too many scattered, undocumented
# dependency paths under $HOME for that to ever be exhaustive. Instead:
# $HOME is readable by default (everything these tools need just works),
# and only the specific sensitive paths below are explicitly masked with
# an empty tmpfs. This is a deliberately weaker guarantee than full
# allowlisting -- a compromised game could still read misc dotfiles/cache
# under $HOME that aren't on the deny list below -- but it's the
# sustainable tradeoff: it still blocks credentials, your Nix config
# repo, and personal documents, without an unbounded discovery loop.
set -euo pipefail

GAME_DIR="${GAMEDIR:-$PWD}"
PFX_DIR="${WINEPREFIX:-$HOME/Games/prefixes/default}"

mkdir -p "$PFX_DIR"

NET_ARGS=(--unshare-net)
if [ "${SANDBOX_ALLOW_NET:-0}" = "1" ]; then
    NET_ARGS=()
fi

DENY_ARGS=()
for p in "$HOME/.ssh" "$HOME/.gnupg" "$HOME/nix" "$HOME/Documents" \
         "$HOME/Downloads" "$HOME/.mozilla" \
         "$HOME/.config/BraveSoftware" "$HOME/.config/google-chrome"; do
    [ -e "$p" ] && DENY_ARGS+=(--tmpfs "$p")
done

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
    --ro-bind "$HOME" "$HOME" \
    "${DENY_ARGS[@]}" \
    --bind "$GAME_DIR" "$GAME_DIR" \
    --bind "$PFX_DIR" "$PFX_DIR" \
    \
    --chdir "$GAME_DIR" \
    --setenv HOME "$HOME" \
    --setenv WINEPREFIX "$PFX_DIR" \
    --setenv GAMEDIR "$GAME_DIR" \
    \
    "$@"
