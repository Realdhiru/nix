#!/usr/bin/env bash
# Cycle wallpaper left/right with hardware-accelerated awww transitions
set -euo pipefail

DIR="${1:-next}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NEXT_INFO=$(python3 - "$DIR" << 'PYEOF'
import os, sys, json

direction = sys.argv[1] if len(sys.argv) > 1 else "next"
cache_dir = os.path.expanduser("~/.cache")
index_file = os.path.join(cache_dir, "quickshell/wallpaper_index.json")
target_txt = os.path.join(cache_dir, "target_wallpaper.txt")
current_txt = os.path.join(cache_dir, "current_wallpaper.txt")

cur_path = ""
for cand in (target_txt, current_txt):
    if os.path.exists(cand):
        try:
            with open(cand) as f:
                c = f.read().strip()
                if c:
                    cur_path = c
                    break
        except Exception:
            pass

cur_name = os.path.basename(cur_path) if cur_path else ""

items = []
if os.path.exists(index_file):
    try:
        with open(index_file) as f:
            data = json.load(f)
            items = data.get("items", [])
    except Exception:
        pass

if not items:
    wall_dir = os.path.expanduser("~/Pictures/Wallpapers")
    for root, dirs, files in os.walk(wall_dir):
        if "previews" in root or "scripts" in root:
            continue
        for fn in files:
            ext = os.path.splitext(fn)[1].lower()
            if ext in [".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".mkv", ".webm"]:
                items.append({
                    "fileName": fn,
                    "filePath": os.path.join(root, fn),
                    "isVideo": ext in [".mp4", ".mkv", ".webm"],
                    "band": 0,
                    "colorKey": 0.0
                })

def get_clean_name(name):
    if not name: return ""
    s = str(name)
    if s.startswith("000_"): s = s[4:]
    if len(s) > 33 and s[32] == '_':
        try:
            int(s[:32], 16)
            s = s[33:]
        except ValueError:
            pass
    return s

def sort_key(item):
    fn = item.get("fileName", "")
    clean = get_clean_name(fn)
    fn_lower = clean.lower()
    is_vid = item.get("isVideo", False)
    if fn_lower.endswith(".gif"):
        t_rank = 0
    elif is_vid:
        t_rank = 2
    else:
        t_rank = 1
    band = item.get("band", 1)
    key = item.get("colorKey", 0.0)
    return (t_rank, -band, key, fn_lower)

sorted_items = sorted(items, key=sort_key)
if not sorted_items:
    sys.exit(1)

cur_idx = -1
for i, item in enumerate(sorted_items):
    if item.get("filePath") == cur_path or item.get("fileName") == cur_name:
        cur_idx = i
        break

if cur_idx == -1:
    cur_idx = 0

step = 1 if direction in ("next", "right", "+1") else -1
next_idx = (cur_idx + step) % len(sorted_items)
target = sorted_items[next_idx]
target_path = target.get("filePath")

try:
    with open(target_txt, "w") as f:
        f.write(target_path + "\n")
except Exception:
    pass

trans = "right" if step > 0 else "left"
print(f"{target_path}\t{trans}")
PYEOF
)

if [ -n "$NEXT_INFO" ]; then
    TARGET_PATH=$(echo "$NEXT_INFO" | cut -f1)
    TRANS_TYPE=$(echo "$NEXT_INFO" | cut -f2)
    exec "$SCRIPT_DIR/set_wallpaper.sh" "$TARGET_PATH" "$TRANS_TYPE" "0.18" "120"
fi
