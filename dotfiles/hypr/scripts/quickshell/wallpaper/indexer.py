#!/usr/bin/env python3
import os
import sys
import json
import time
import subprocess
from concurrent.futures import ThreadPoolExecutor

def get_color_bucket(hex_str):
    if not hex_str:
        return "Dark"
    hex_str = str(hex_str).strip().replace("#", "")
    if len(hex_str) > 6:
        hex_str = hex_str[:6]
    if len(hex_str) != 6:
        return "Dark"
    try:
        r = int(hex_str[0:2], 16) / 255.0
        g = int(hex_str[2:4], 16) / 255.0
        b = int(hex_str[4:6], 16) / 255.0
    except ValueError:
        return "Dark"

    mx = max(r, g, b)
    mn = min(r, g, b)
    d = mx - mn
    h = 0.0
    s = 0.0 if mx == 0 else d / mx
    v = mx

    if mx != mn:
        if mx == r:
            h = (g - b) / d + (6.0 if g < b else 0.0)
        elif mx == g:
            h = (b - r) / d + 2.0
        else:
            h = (r - g) / d + 4.0
        h /= 6.0
    h *= 360.0

    if s < 0.14:
        if v >= 0.55:
            return "White"
        else:
            return "Dark"
    if v < 0.15:
        return "Dark"

    if h >= 340 or h < 15:
        return "Red"
    if 15 <= h < 75:
        return "Orange"
    if 75 <= h < 165:
        return "Green"
    if 165 <= h < 255:
        return "Blue"
    if 255 <= h < 340:
        return "Purple"
    return "Dark"

def extract_color(filepath):
    for cmd in ["magick", "convert"]:
        try:
            out = subprocess.check_output(
                [cmd, f"{filepath}[0]", "-resize", "1x1!", "-format", "%[hex:p{0,0}]", "info:-"],
                stderr=subprocess.DEVNULL,
                timeout=4
            ).decode("utf-8").strip()
            if len(out) >= 6:
                return f"#{out[:6]}"
        except Exception:
            continue
    return "#1e1e2e"

def process_file(file_info, cached_map):
    fname, fpath, mtime, size, is_video = file_info
    furl = f"file://{fpath}"

    existing = cached_map.get(fpath)
    if existing and existing.get("mtime") == mtime and existing.get("size") == size:
        hex_color = existing.get("hex", "#1e1e2e")
        bucket = get_color_bucket(hex_color) if not is_video else "Videos"
        existing["bucket"] = bucket
        return existing

    if is_video:
        return {
            "fileName": fname,
            "filePath": fpath,
            "fileUrl": furl,
            "isVideo": True,
            "hex": "#808080",
            "bucket": "Videos",
            "mtime": mtime,
            "size": size
        }
    else:
        hex_color = extract_color(fpath)
        bucket = get_color_bucket(hex_color)
        return {
            "fileName": fname,
            "filePath": fpath,
            "fileUrl": furl,
            "isVideo": False,
            "hex": hex_color,
            "bucket": bucket,
            "mtime": mtime,
            "size": size
        }

def run_indexing(src_dir, output_file):
    cached_map = {}
    if os.path.exists(output_file):
        try:
            with open(output_file, "r") as f:
                old_data = json.load(f)
                for item in old_data.get("items", []):
                    if item.get("filePath"):
                        cached_map[item.get("filePath")] = item
        except Exception:
            cached_map = {}

    img_exts = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
    vid_exts = {".mp4", ".mkv", ".mov", ".webm"}

    entries = []
    for root, dirs, files in os.walk(src_dir):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d != "previews"]
        for fname in files:
            if fname.startswith("."):
                continue
            ext = os.path.splitext(fname)[1].lower()
            if ext not in img_exts and ext not in vid_exts:
                continue
            fpath = os.path.join(root, fname)
            try:
                st = os.stat(fpath)
                mtime = int(st.st_mtime)
                size = int(st.st_size)
            except Exception:
                continue
            is_video = ext in vid_exts
            entries.append((fname, fpath, mtime, size, is_video))

    workers = min(12, max(4, os.cpu_count() or 4))
    items_map = {}
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(process_file, entry, cached_map) for entry in entries]
        for f in futures:
            try:
                res = f.result()
                if res and res.get("filePath"):
                    items_map[res["filePath"]] = res
            except Exception:
                pass

    items = [items_map[k] for k in sorted(items_map.keys())]

    output_data = {
        "srcDir": os.path.abspath(src_dir),
        "updatedAt": int(time.time()),
        "items": items
    }

    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    tmp_out = f"{output_file}.tmp"
    with open(tmp_out, "w") as f:
        json.dump(output_data, f, indent=2)
    os.replace(tmp_out, output_file)

if __name__ == "__main__":
    src_dir = os.path.expanduser("~/Pictures/Wallpapers")
    output_file = os.path.expanduser("~/.cache/quickshell/wallpaper_index.json")
    if len(sys.argv) > 1:
        src_dir = os.path.expanduser(sys.argv[1])
    if len(sys.argv) > 2:
        output_file = os.path.expanduser(sys.argv[2])
    run_indexing(src_dir, output_file)
