#!/usr/bin/env bash
WALL="$1"
CACHE_FILE="$HOME/.cache/matugen/qs_colors.json"

# 1. Calculate average saturation (0-100 scale)
sat=$(magick "$WALL" -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info:)

# 2. Extract colors or set fallback
# If saturation is < 5 (effectively B&W), use the Off-White fallback
if (( $(echo "$sat < 5" | bc -l) )); then
    main="#d1d1d1"
    second="#d1d1d1"
else
    # Otherwise, extract dominant colors from the image
    colors=$(magick "$WALL" -resize 256x256 -colors 2 -format "%[hex:p{0,0}] %[hex:p{1,0}]" info:)
    main=$(echo $colors | awk '{print "#"$1}')
    second=$(echo $colors | awk '{print "#"$2}')
fi

# 3. Create raw JSON
# We include 'mauve' and 'blue' here so your existing QML files 
# automatically pick up the new colors without needing edits.
cat << JSON > "$CACHE_FILE"
{
  "primary": "$main",
  "secondary": "$second",
  "base": "#11111b",
  "text": "$second",
  "surface": "$main",
  "mauve": "$main",
  "blue": "$main"
}
JSON