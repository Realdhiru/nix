#!/usr/bin/env bash
#
# fuzzel_file_search.sh -- High-speed interactive fuzzy file finder via fd + fuzzel
#
set -euo pipefail

# Directories to search (skips heavy build/cache/git trees)
SEARCH_DIRS=(
    "$HOME/Documents"
    "$HOME/Downloads"
    "$HOME/Pictures"
    "$HOME/Videos"
    "$HOME/Music"
    "$HOME/nix"
    "$HOME/Desktop"
)

# Filter out non-existent directories
VALID_DIRS=()
for d in "${SEARCH_DIRS[@]}"; do
    [ -d "$d" ] && VALID_DIRS+=("$d")
done

if [ ${#VALID_DIRS[@]} -eq 0 ]; then
    VALID_DIRS=("$HOME")
fi

# Use fd to rapidly index files while ignoring junk directories
SELECTED_FILE=$(
    fd --hidden --follow --strip-cwd-prefix \
       --exclude .git \
       --exclude node_modules \
       --exclude .cache \
       --exclude .cargo \
       --exclude .rustup \
       --exclude .local/share/Trash \
       --exclude .direnv \
       --type f \
       . "${VALID_DIRS[@]}" 2>/dev/null | \
    fuzzel --dmenu \
           --placeholder="Search files..." \
           --prompt="📄 " \
           --lines=10 \
           --width=55 2>/dev/null || true
)

if [ -n "$SELECTED_FILE" ] && [ -e "$SELECTED_FILE" ]; then
    # Open with default application handler
    xdg-open "$SELECTED_FILE" >/dev/null 2>&1 &
fi
