#!/usr/bin/env bash
# Fast wallpaper indexer - native awk/bash generator (replaces heavy python/sklearn)
SRC_DIR="${1:-$HOME/Pictures/Wallpapers}"
OUTPUT_FILE="${2:-$HOME/.cache/quickshell/wallpaper_index.json}"
CACHE_DIR="${QS_CACHE_WALLPAPER_PICKER:-$HOME/.cache/quickshell/wallpaper_picker}"
COLOR_DIR="$CACHE_DIR/colors_markers"

mkdir -p "$(dirname "$OUTPUT_FILE")"

if [ -d "$COLOR_DIR" ]; then
    ls "$COLOR_DIR" 2>/dev/null | awk -F'_' -v src="$SRC_DIR" '
    BEGIN {
        print "{\"srcDir\":\"" src "\",\"updatedAt\":" systime() ",\"items\":[" ;
        first=1;
    }
    {
        hash=$1;
        hex=tolower($NF);
        cat="Dark";
        for(i=2; i<=NF; i++) {
            if ($i == "CAT") {
                cat=toupper(substr($(i+1),1,1)) substr(tolower($(i+1)),2);
                break;
            }
        }
        fname = substr($0, length(hash)+2);
        sub(/_CAT_.*/, "", fname);
        sub(/_HEX_.*/, "", fname);
        if (fname == "") next;

        if (!first) printf ",\n";
        first=0;
        printf "{\"fileName\":\"%s\",\"hex\":\"#%s\",\"bucket\":\"%s\",\"theme\":\"%s\"}", fname, hex, cat, tolower(cat);
    }
    END {
        print "\n]}"
    }' > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
fi
