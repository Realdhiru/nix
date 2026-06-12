#!/usr/bin/env bash

# Settings based on your layout
VAULT_DIR="$HOME/Life/Obsidian"
VAULT_NAME="Obsidian"
YEAR=$(date +%Y)
DAY=$(date +%d)
MONTH=$(date +%m)
FILENAME="${DAY}.${MONTH}"
FILEPATH="Diary/${YEAR}/${FILENAME}.md"
FULL_PATH="${VAULT_DIR}/${FILEPATH}"
CONTENTS_PATH="${VAULT_DIR}/Diary/Contents.md"

# Ensure the directory exists
mkdir -p "${VAULT_DIR}/Diary/${YEAR}"

# 1. Create diary file if it doesn't exist
if [ ! -f "$FULL_PATH" ]; then
    echo "#diary" > "$FULL_PATH"
    echo "" >> "$FULL_PATH"
fi

# 2. Update Contents.md if the link isn't already there
if [ -f "$CONTENTS_PATH" ]; then
    if ! grep -q "\[\[${FILENAME}\]\]" "$CONTENTS_PATH"; then
        # Use awk to inject the link dynamically into the correct section without breaking formatting
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
        ' "$CONTENTS_PATH" > "${CONTENTS_PATH}.tmp" && mv "${CONTENTS_PATH}.tmp" "$CONTENTS_PATH"
    fi
else
    # Create the Contents file if missing entirely
    mkdir -p "$(dirname "$CONTENTS_PATH")"
    echo "## ${YEAR}" > "$CONTENTS_PATH"
    echo "- [[${FILENAME}]]" >> "$CONTENTS_PATH"
fi

# 3. Open the specific note directly inside Obsidian using its URI protocol
xdg-open "obsidian://open?vault=${VAULT_NAME}&file=Diary/${YEAR}/${FILENAME}"
