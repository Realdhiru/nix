#!/usr/bin/env bash
#
# fuzzel_file_search.sh -- Ultra-fast live fuzzy file search with icons and compact Spotlight geometry
#
set -euo pipefail

SEARCH_DIRS=(
    "$HOME/Downloads"
    "$HOME/Pictures"
    "$HOME/Videos"
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/Music"
    "$HOME/nix"
)

VALID_DIRS=()
for d in "${SEARCH_DIRS[@]}"; do
    [ -d "$d" ] && VALID_DIRS+=("$d")
done

if [ ${#VALID_DIRS[@]} -eq 0 ]; then
    VALID_DIRS=("$HOME")
fi

FUZZEL_EXTRA_ARGS=()
CURRENT_PROFILE="$(cat "$HOME/.cache/qs_power_profile" 2>/dev/null || cat /tmp/qs_power_profile 2>/dev/null || echo "")"
if [ -f "$HOME/.cache/wallpaper_killed" ] || \
   [ -f "$HOME/.cache/gaming_mode" ] || \
   [ "$CURRENT_PROFILE" = "power-saver" ]; then
    FUZZEL_EXTRA_ARGS+=(--background-color=111111ff)
fi

SELECTED_FILE=$(
    fd -H --max-depth 7 \
       --exclude .git \
       --exclude node_modules \
       --exclude .cache \
       --exclude .cargo \
       --exclude .rustup \
       --exclude .local/share \
       --exclude .mozilla \
       --exclude .direnv \
       --type f . \
       "${VALID_DIRS[@]}" 2>/dev/null | \
    awk -v home="$HOME" '{
        full = $0;
        sub(home "/?", "~/", full);
        n = split(full, parts, "/");
        fname = parts[n];
        dir = "";
        for (i = 1; i < n; i++) {
            dir = (i == 1 ? parts[i] : dir "/" parts[i]);
        }
        ext = "";
        if (match(fname, /\.[a-zA-Z0-9]+$/)) {
            ext = tolower(substr(fname, RSTART + 1));
        }
        icon = "text-x-generic";
        glyph = "󰈔";
        if (ext ~ /^(png|jpg|jpeg|webp|gif|svg|bmp)$/) { icon = "image-x-generic"; glyph = "󰋩"; }
        else if (ext ~ /^(mp4|mkv|avi|mov|webm|flv)$/) { icon = "video-x-generic"; glyph = "󰕧"; }
        else if (ext ~ /^(mp3|flac|wav|ogg|m4a|opus)$/) { icon = "audio-x-generic"; glyph = "󰎈"; }
        else if (ext ~ /^(pdf|djvu|epub)$/) { icon = "application-pdf"; glyph = "󰈦"; }
        else if (ext ~ /^(zip|tar|gz|bz2|xz|7z|rar)$/) { icon = "package-x-generic"; glyph = "󰛫"; }
        else if (ext ~ /^(nix|lua|sh|bash|py|js|ts|rs|go|c|cpp|h|hpp)$/) { icon = "text-x-script"; glyph = "󰅩"; }
        else if (ext ~ /^(md|txt|org|json|yaml|yml|toml|conf|ini)$/) { icon = "text-x-generic"; glyph = "󰈙"; }
        printf "%s %-32s  %s\0icon\x1f%s\t%s\n", glyph, fname, dir, icon, $0;
    }' | \
    fuzzel --dmenu \
           "${FUZZEL_EXTRA_ARGS[@]}" \
           --hide-before-typing \
           --anchor=center \
           --width=46 \
           --lines=5 \
           --line-height=26 \
           --font="JetBrainsMono Nerd Font:size=11" \
           --icon-theme=Papirus-Dark \
           --horizontal-pad=18 \
           --vertical-pad=12 \
           --inner-pad=8 \
           --with-nth=1 \
           --match-nth=1 \
           --accept-nth=2 \
           --nth-delimiter=$'\t' \
           --prompt="  " \
           --placeholder="Type to search files..." 2>/dev/null || true
)

if [ -n "$SELECTED_FILE" ] && [ -e "$SELECTED_FILE" ]; then
    DIR_PATH=$(dirname "$SELECTED_FILE")
    pcmanfm-qt "$DIR_PATH" >/dev/null 2>&1 &
fi
