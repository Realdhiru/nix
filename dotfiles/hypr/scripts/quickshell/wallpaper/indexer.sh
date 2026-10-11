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
function hex2score(hex, res,   r, g, b, max_c, min_c, d, l, s, h) {
    if (length(hex) < 6) { res["band"] = 0; res["key"] = 0; return; }
    r = strtonum("0x" substr(hex, 1, 2)) / 255.0;
    g = strtonum("0x" substr(hex, 3, 2)) / 255.0;
    b = strtonum("0x" substr(hex, 5, 2)) / 255.0;
    max_c = (r > g ? (r > b ? r : b) : (g > b ? g : b));
    min_c = (r < g ? (r < b ? r : b) : (g < b ? g : b));
    d = max_c - min_c;
    l = (max_c + min_c) / 2.0;
    s = 0.0;
    h = 0.0;
    if (d > 0.00001) {
        s = (l > 0.5) ? d / (2.0 - max_c - min_c) : d / (max_c + min_c);
        if (max_c == r) {
            h = (g - b) / d + (g < b ? 6.0 : 0.0);
        } else if (max_c == g) {
            h = (b - r) / d + 2.0;
        } else {
            h = (r - g) / d + 4.0;
        }
        h *= 60.0;
    }
    if (s < 0.14 || l < 0.08 || l > 0.92) {
        res["band"] = 0;
        res["key"] = l * 100.0;
    } else {
        res["band"] = 1;
        res["key"] = h;
    }
}
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

            hex2score(hex, sc);

            if (!first) printf ",\n";
            first = 0;
            printf "{\"fileName\":\"%s\",\"filePath\":\"%s\",\"hex\":\"#%s\",\"band\":%d,\"colorKey\":%.2f,\"bucket\":\"%s\",\"theme\":\"%s\",\"isVideo\":%s}", fn, real_path, hex, sc["band"], sc["key"], cat, tolower(cat), is_vid;
        }
        close(cmd);
        print "\n]}";
    }
    ' > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
elif [ -d "$COLOR_DIR" ]; then
    ls "$COLOR_DIR" 2>/dev/null | gawk -F'_' -v src="$SRC_DIR" '
    function hex2score(hex, res,   r, g, b, max_c, min_c, d, l, s, h) {
        if (length(hex) < 6) { res["band"] = 0; res["key"] = 0; return; }
        r = strtonum("0x" substr(hex, 1, 2)) / 255.0;
        g = strtonum("0x" substr(hex, 3, 2)) / 255.0;
        b = strtonum("0x" substr(hex, 5, 2)) / 255.0;
        max_c = (r > g ? (r > b ? r : b) : (g > b ? g : b));
        min_c = (r < g ? (r < b ? r : b) : (g < b ? g : b));
        d = max_c - min_c;
        l = (max_c + min_c) / 2.0;
        s = 0.0;
        h = 0.0;
        if (d > 0.00001) {
            s = (l > 0.5) ? d / (2.0 - max_c - min_c) : d / (max_c + min_c);
            if (max_c == r) {
                h = (g - b) / d + (g < b ? 6.0 : 0.0);
            } else if (max_c == g) {
                h = (b - r) / d + 2.0;
            } else {
                h = (r - g) / d + 4.0;
            }
            h *= 60.0;
        }
        if (s < 0.14 || l < 0.08 || l > 0.92) {
            res["band"] = 0;
            res["key"] = l * 100.0;
        } else {
            res["band"] = 1;
            res["key"] = h;
        }
    }
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

        hex2score(hex, sc);

        if (!first) printf ",\n";
        first=0;
        printf "{\"fileName\":\"%s\",\"filePath\":\"%s/%s\",\"hex\":\"#%s\",\"band\":%d,\"colorKey\":%.2f,\"bucket\":\"%s\",\"theme\":\"%s\"}", fname, src, fname, hex, sc["band"], sc["key"], cat, tolower(cat);
    }
    END {
        print "\n]}"
    }' > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
fi

PATHS_FILE="${OUTPUT_FILE%/*}/wallpaper_paths.txt"
if [ -f "$OUTPUT_FILE" ]; then
    jq -r '
      def clean_name:
        if startswith("000_") then .[4:]
        elif (length > 33 and .[32:33] == "_") then .[33:]
        else . end;
      def type_rank:
        (.fileName | ascii_downcase) as $fn |
        if ($fn | endswith(".gif")) then 1
        elif (.isVideo == true or ($fn | test("\\.(mp4|mkv|webm)$"))) then 2
        else 0 end;
      .items
      | sort_by(
          type_rank,
          -(.band // 0),
          (.colorKey // 0),
          (.fileName | clean_name | ascii_downcase)
        )
      | .[].filePath
    ' "$OUTPUT_FILE" > "${PATHS_FILE}.tmp" 2>/dev/null && mv -f "${PATHS_FILE}.tmp" "$PATHS_FILE" 2>/dev/null || true
fi
