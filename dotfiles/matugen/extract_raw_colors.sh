#!/usr/bin/env bash
WALL="$1"
CACHE_FILE="$HOME/.cache/matugen/qs_colors.json"

# Extract dominant color (Main) and secondary (Text/Secondary)
colors=$(magick "$WALL" -resize 256x256 -colors 2 -format "%[hex:p{0,0}] %[hex:p{1,0}]" info:)
main=$(echo $colors | awk '{print "#"$1}')
second=$(echo $colors | awk '{print "#"$2}')

# Create raw JSON
cat << JSON > "$CACHE_FILE"
{
  "primary": "$main",
  "secondary": "$second",
  "base": "#11111b",
  "text": "$second",
  "surface": "$main"
}
JSON
