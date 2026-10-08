#!/usr/bin/env bash
# Fast wallpaper indexer - native awk/bash generator (replaces heavy python/sklearn)
SRC_DIR="${1:-$HOME/Pictures/Wallpapers}"
OUTPUT_FILE="${2:-$HOME/.cache/quickshell/wallpaper_index.json}"
CACHE_DIR="${QS_CACHE_WALLPAPER_PICKER:-$HOME/.cache/quickshell/wallpaper_picker}"
COLOR_DIR="$CACHE_DIR/colors_markers"

mkdir -p "$(dirname "$OUTPUT_FILE")"

FLAT_DIR="$CACHE_DIR/flat"

if [ -d "$FLAT_DIR" ] && [ -d "$COLOR_DIR" ]; then
    gawk -v src="$SRC_DIR" '
    BEGIN {
        while (("ls " ENVIRON["HOME"] "/.cache/quickshell/wallpaper_picker/colors_markers 2>/dev/null" | getline m) > 0) {
            h = substr(m, 1, 32);
            hex = tolower(substr(m, length(m)-5));
            cat = "Dark";
            n = split(m, parts, "_");
            for (i=1; i<=n; i++) {
                if (parts[i] == "CAT") {
                    cat = toupper(substr(parts[i+1],1,1)) tolower(substr(parts[i+1],2));
                    break;
                }
            }
            marker_hex[h] = hex;
            marker_cat[h] = cat;
        }
        close("ls " ENVIRON["HOME"] "/.cache/quickshell/wallpaper_picker/colors_markers 2>/dev/null");

        now = systime();
        printf "{\"srcDir\":\"%s\",\"updatedAt\":%d,\"items\":[\n", src, now;
        first = 1;
        cmd = "find " ENVIRON["HOME"] "/.cache/quickshell/wallpaper_picker/flat -type l -printf \"%f\\t%l\\n\" 2>/dev/null";
        while ((cmd | getline l) > 0) {
            split(l, f_target, "\t");
            fn_sym = f_target[1];
            real_path = f_target[2];
            h = substr(fn_sym, 1, 32);
            fn = substr(fn_sym, 34);
            if (fn == "") continue;
            hex = marker_hex[h];
            if (hex == "") hex = "1e1e2e";
            cat = marker_cat[h];
            if (cat == "") cat = "Dark";
            is_vid = (fn ~ /\.(mp4|mkv|webm)$/) ? "true" : "false";

            if (!first) printf ",\n";
            first = 0;
            printf "{\"fileName\":\"%s\",\"filePath\":\"%s\",\"hex\":\"#%s\",\"bucket\":\"%s\",\"theme\":\"%s\",\"isVideo\":%s}", fn, real_path, hex, cat, tolower(cat), is_vid;
        }
        close(cmd);
        print "\n]}";
    }
    ' > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
elif [ -d "$COLOR_DIR" ]; then
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
        printf "{\"fileName\":\"%s\",\"filePath\":\"%s/%s\",\"hex\":\"#%s\",\"bucket\":\"%s\",\"theme\":\"%s\"}", fname, src, fname, hex, cat, tolower(cat);
    }
    END {
        print "\n]}"
    }' > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
fi
