#!/usr/bin/env bash
#
# fuzzel_menu.sh -- Unified Fuzzel runner for Applications & File Search
# Consolidates application launcher and spotlight file finder with adaptive
# opacity and compact 2x HiDPI scaling matching QuickShell.
#
set -euo pipefail

MODE="${1:-app}"
MODE_FILE="${XDG_RUNTIME_DIR:-/tmp}/fuzzel_mode"

# If fuzzel is already open: toggle off if same mode, or switch seamlessly if different mode
if pgrep -x fuzzel >/dev/null 2>&1; then
    ACTIVE_MODE="$(cat "$MODE_FILE" 2>/dev/null || echo "")"
    if [ "$ACTIVE_MODE" = "$MODE" ]; then
        pkill -x fuzzel || true
        rm -f "$MODE_FILE"
        exit 0
    fi
    pkill -x fuzzel || true
    # Brief yield to let Wayland layer surface release before re-spawning
    sleep 0.05
fi

echo "$MODE" > "$MODE_FILE"

# Detect power & compositor state for solid background fallback
CURRENT_PROFILE="$(cat "$HOME/.cache/qs_power_profile" 2>/dev/null || cat /tmp/qs_power_profile 2>/dev/null || echo "")"
SOLID_BG=false
if [ -f "$HOME/.cache/wallpaper_killed" ] || \
   [ -f "$HOME/.cache/gaming_mode" ] || \
   [ "$CURRENT_PROFILE" = "power-saver" ]; then
    SOLID_BG=true
fi

case "$MODE" in
    app|apps)
        EXTRA_ARGS=()
        if [ "$SOLID_BG" = true ]; then
            EXTRA_ARGS+=(--background-color=111111ff)
        fi
        exec fuzzel "${EXTRA_ARGS[@]}"
        ;;

    file|files)
        FUZZEL_ARGS=(
            --dmenu
            --match-mode=exact
            --hide-before-typing
            --anchor=center
            --width=48
            --lines=6
            --line-height=22
            --font="JetBrainsMono Nerd Font:size=9.5"
            --icon-theme=buuf-nestort
            --horizontal-pad=14
            --vertical-pad=10
            --inner-pad=6
            --border-radius=12
            --layer=overlay
            --keyboard-focus=exclusive
            --with-nth=1
            --match-nth=3
            --accept-nth=2
            --nth-delimiter=$'\t'
            --prompt="  "
            --placeholder="Type to search files..."
        )

        if [ "$SOLID_BG" = true ]; then
            FUZZEL_ARGS+=(--background-color=111111ff)
        fi

        SELECTED_FILE=$(
            fd --max-depth 6 \
               --exclude .git \
               --exclude node_modules \
               --exclude .cache \
               --exclude .cargo \
               --exclude .rustup \
               --exclude .local \
               --exclude .mozilla \
               --exclude .direnv \
               --exclude .gemini \
               --exclude .var \
               --exclude .steam \
               --exclude .wine \
               --exclude .npm \
               --exclude .vscode-oss \
               --exclude .vscode-oss-shared \
               --exclude .android \
               --exclude .aws \
               --exclude .bun \
               --exclude .terraform.d \
               --exclude target \
               --exclude dist \
               --exclude build \
               --exclude '*/Session Storage' \
               --exclude '*/Local Storage' \
               --exclude '*/IndexedDB' \
               --exclude '*/Service Worker' \
               --exclude '*/Partitions' \
               --exclude '*/Crash Reports' \
               --exclude '*/Crashpad' \
               --exclude '*/GPUCache' \
               --exclude '*/Code Cache' \
               --exclude '*/blob_storage' \
               --type f . \
               "$HOME" "$HOME/.config" 2>/dev/null | \
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
                glyph = "󰈔";
                tags = "/file";
                if (ext ~ /^(png|jpg|jpeg|webp|gif|svg|bmp|ico|tiff|avif|raw)$/) {
                    glyph = "󰋩";
                    tags = "/image /images /img /photo /pic";
                } else if (ext ~ /^(mp4|mkv|avi|mov|webm|flv|wmv|m4v|mpg|mpeg)$/) {
                    glyph = "󰕧";
                    tags = "/video /videos /vid /movie";
                } else if (ext ~ /^(mp3|flac|wav|ogg|m4a|opus|aac|wma|mid|midi)$/) {
                    glyph = "󰎈";
                    tags = "/audio /music /song /sound";
                } else if (ext ~ /^(pdf|djvu|epub)$/) {
                    glyph = "󰈦";
                    tags = "/doc /docs /document /pdf";
                } else if (ext ~ /^(doc|docx|odt|txt|rtf|md|org)$/) {
                    glyph = "󰈙";
                    tags = "/doc /docs /document /text";
                } else if (ext ~ /^(csv|xls|xlsx|ods)$/) {
                    glyph = "󰈛";
                    tags = "/doc /docs /document /sheet";
                } else if (ext ~ /^(ppt|pptx|odp)$/) {
                    glyph = "󰈧";
                    tags = "/doc /docs /document /slides";
                } else if (ext ~ /^(zip|tar|gz|bz2|xz|7z|rar|zst|tgz)$/) {
                    glyph = "󰛫";
                    tags = "/archive /zip /tar";
                } else if (ext ~ /^(json|yaml|yml|toml|conf|ini|desktop)$/) {
                    glyph = "󰒓";
                    tags = "/code /conf /config";
                } else if (ext ~ /^(nix|lua|sh|bash|zsh|fish|py|js|ts|jsx|tsx|rs|go|c|cpp|h|hpp)$/) {
                    glyph = "󰅩";
                    tags = "/code /dev /script";
                }
                if (ext != "") {
                    tags = tags " /" ext;
                }
                printf "%s %-28s  %s\t%s\t%s\t%s\t%s\n", glyph, fname, dir, $0, fname, dir, tags;
            }' | \
            fuzzel "${FUZZEL_ARGS[@]}" 2>/dev/null || true
        )

        if [ -n "$SELECTED_FILE" ] && [ -e "$SELECTED_FILE" ]; then
            DIR_PATH="$SELECTED_FILE"
            [ -f "$SELECTED_FILE" ] && DIR_PATH=$(dirname "$SELECTED_FILE")
            pcmanfm-qt "$DIR_PATH" >/dev/null 2>&1 &
        fi
        ;;

    emoji|emojis|glyph|glyphs)
        SUBMODE="emoji"
        [ "$MODE" = "glyph" ] || [ "$MODE" = "glyphs" ] && SUBMODE="glyph"

        EMOJI_DB="$HOME/.config/hypr/assets/emoji.db"
        [ -f "$EMOJI_DB" ] || EMOJI_DB="$HOME/nix/dotfiles/hypr/assets/emoji.db"
        [ -f "$EMOJI_DB" ] || EMOJI_DB="$HOME/Projects/emoji.db"

        GLYPH_DB="$HOME/.config/hypr/assets/glyph.db"
        [ -f "$GLYPH_DB" ] || GLYPH_DB="$HOME/nix/dotfiles/hypr/assets/glyph.db"
        [ -f "$GLYPH_DB" ] || GLYPH_DB="$HOME/Projects/glyph.db"

        QUERY=""
        while true; do
            if [ "$SUBMODE" = "emoji" ]; then
                DB_PATH="$EMOJI_DB"
                FONT="Noto Color Emoji,JetBrainsMono Nerd Font:size=11"
                PROMPT="󰞅 "
                PLACEHOLDER="Search emojis...  [Tab: Glyphs]"
            else
                DB_PATH="$GLYPH_DB"
                FONT="JetBrainsMono Nerd Font,Noto Color Emoji:size=11"
                PROMPT="󰄛 "
                PLACEHOLDER="Search nerd glyphs...  [Tab: Emojis]"
            fi

            if [ ! -f "$DB_PATH" ]; then
                notify-send "DB missing"
                exit 1
            fi

            FUZZEL_ARGS=(
                --dmenu
                --match-mode=fzf
                --anchor=center
                --width=46
                --lines=8
                --line-height=26
                --font="$FONT"
                --horizontal-pad=16
                --vertical-pad=10
                --inner-pad=6
                --border-radius=12
                --layer=overlay
                --keyboard-focus=exclusive
                --with-nth=1
                --match-nth=3
                --accept-nth=2
                --nth-delimiter=$'\t'
                --prompt="$PROMPT"
                --placeholder="$PLACEHOLDER"
                --override="key-bindings.execute-or-next=none"
                --override="key-bindings.custom-1=Tab"
            )

            [ -n "$QUERY" ] && FUZZEL_ARGS+=(--search="$QUERY")

            if [ "$SOLID_BG" = true ]; then
                FUZZEL_ARGS+=(--background-color=111111ff)
            fi

            SELECTION=""
            EXIT_CODE=0
            SELECTION=$(fuzzel "${FUZZEL_ARGS[@]}" < "$DB_PATH" 2>/dev/null) || EXIT_CODE=$?

            if [ "$EXIT_CODE" -eq 10 ]; then
                # Tab pressed: toggle mode and preserve current selection/typed prefix
                QUERY="$SELECTION"
                if [ "$SUBMODE" = "emoji" ]; then
                    SUBMODE="glyph"
                else
                    SUBMODE="emoji"
                fi
                continue
            elif [ "$EXIT_CODE" -eq 0 ] && [ -n "$SELECTION" ]; then
                printf "%s" "$SELECTION" | wl-copy --type text/plain\;charset=utf-8
                notify-send "Copied $SELECTION"
                break
            else
                # User pressed Escape or cancelled
                break
            fi
        done
        ;;

    *)
        echo "Usage: $0 {app|file|emoji|glyph}"
        exit 1
        ;;
esac
