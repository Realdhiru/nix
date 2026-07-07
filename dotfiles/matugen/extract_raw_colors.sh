# ==> /home/realdhiru/nix/dotfiles/matugen/extract_raw_colors.sh <==
#!/usr/bin/env bash
WALL="$1"
CACHE_FILE="$HOME/.cache/matugen/qs_colors.json"

# 1. $O(1) Color Extraction via Affine Transform
# Resizing to exactly 2x1 pixels instantly averages the image into two dominant tones, skipping heavy quantization.
read -r main second <<< "$(magick "$WALL" -resize '2x1!' -format "#%[hex:p{0,0}] #%[hex:p{1,0}]\n" info:)"

# 2. Memory-Safe Saturation Check
sat=$(magick "$WALL" -resize 16x16 -colorspace HSL -channel s -separate +channel -format "%[fx:mean*100]" info: 2>/dev/null)

if (( $(echo "${sat:-100} < 5" | bc -l) )); then
    main="#d3d3d3"
    second="#a9a9a9"
fi

# 3. Atomic File Writing
# Generates all 22 keys to perfectly match qs_colors.json.template, preventing QML binding desync
cat << JSON > "${CACHE_FILE}.tmp"
{
  "base": "#11111b",
  "mantle": "#181825",
  "crust": "#1e1e2e",
  "text": "$second",
  "subtext0": "$second",
  "subtext1": "$second",
  "surface0": "#313244",
  "surface1": "#45475a",
  "surface2": "#585b70",
  "overlay0": "#6c7086",
  "overlay1": "#7f849c",
  "overlay2": "#9399b2",
  "blue": "$main",
  "sapphire": "$main",
  "peach": "$second",
  "green": "$main",
  "red": "#f38ba8",
  "mauve": "$main",
  "pink": "$main",
  "yellow": "$main",
  "maroon": "#eba0ac",
  "teal": "$main"
}
JSON

mv "${CACHE_FILE}.tmp" "$CACHE_FILE"