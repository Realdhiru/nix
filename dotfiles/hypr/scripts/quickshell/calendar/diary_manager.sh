#!/usr/bin/env bash
set -euo pipefail

# Consolidate date extraction into a single, atomic execution
read -r YEAR MONTH DAY <<< "$(date +'%Y %m %d')"

# Settings based on your layout
VAULT_DIR="$HOME/Life/Obsidian"
VAULT_NAME="Obsidian"
FILENAME="${DAY}.${MONTH}"
FILEPATH="Diary/${YEAR}/${FILENAME}.md"
FULL_PATH="${VAULT_DIR}/${FILEPATH}"
CONTENTS_PATH="${VAULT_DIR}/Diary/Contents.md"

# Ensure the directory exists
mkdir -p "${VAULT_DIR}/Diary/${YEAR}"

# 1. Create diary file if it doesn't exist
if [ ! -f "$FULL_PATH" ]; then
    echo -e "#diary\n" > "$FULL_PATH"
fi

# 2. Update Contents.md if the link isn't already there
if [ -f "$CONTENTS_PATH" ]; then
    if ! grep -q "\[\[${FILENAME}\]\]" "$CONTENTS_PATH"; then
        # Use mktemp for a guaranteed safe, atomic file replacement
        TMP_FILE=$(mktemp)
        
        awk -v year="## ${YEAR}" -v entry="- [[${FILENAME}]]" '
        BEGIN { in_year=0; inserted=0 }
        $0 == year { in_year=1; print; next }
        /^## / && in_year { print entry; inserted=1; in_year=0 }
        { print }
        END {
            if (in_year && !inserted) {
                print entry
            } else if (!in_year && !inserted) {
                print ""
                print year
                print entry
            }
        }
        ' "$CONTENTS_PATH" > "$TMP_FILE"
        
        mv "$TMP_FILE" "$CONTENTS_PATH"
    fi
else
    # Create the Contents file if missing entirely
    mkdir -p "$(dirname "$CONTENTS_PATH")"
    echo -e "## ${YEAR}\n- [[${FILENAME}]]" > "$CONTENTS_PATH"
fi

# 3. Open the specific note directly inside Obsidian using its URI protocol
xdg-open "obsidian://open?vault=${VAULT_NAME}&file=Diary/${YEAR}/${FILENAME}"