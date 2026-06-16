#!/usr/bin/env bash
WALL="$1"
CACHE_FILE="$HOME/.cache/matugen/qs_colors.json"

# Ensure cache directory exists
mkdir -p "$(dirname "$CACHE_FILE")"

# Extract average saturation (0-100)
sat=$(magick "$WALL" -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info:)

# Extract 2 most dominant colors
colors=$(magick "$WALL" -resize 256x256 -colors 2 -format "%[hex:p{0,0}] %[hex:p{1,0}]" info:)
main=$(echo $colors | awk '{print "#"$1}')
second=$(echo $colors | awk '{print "#"$2}')

# Fallback: If image is near-grayscale (sat < 5), use clean monochrome grays
if (( $(echo "$sat < 5" | bc -l) )); then
    main="#a6adc8"
    second="#cdd6f4"
fi

# Create JSON (mapped to your existing template keys)
cat << JSON > "$CACHE_FILE"
{
  "primary": "$main",
  "secondary": "$second",
  "base": "#11111b",
  "text": "$second",
  "subtext0": "$second",
  "mauve": "$main",
  "blue": "$main"
}
JSON