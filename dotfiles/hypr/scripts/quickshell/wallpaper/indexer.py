#!/usr/bin/env python3
"""Indexes wallpaper directory, extracting color metadata and open-set theme classifications."""

import os
import sys
import json
import time
import math
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

# Auto re-exec into Nix environment if needed
try:
    import numpy as np
except ImportError:
    for _cand in (
        "/nix/store/qswcjhjlrf37snr5dzmcp15zvw74cyxq-python3-3.14.7-env/bin/python3",
    ):
        if os.path.exists(_cand):
            os.execv(_cand, [_cand] + sys.argv)
    _cmd = ["nix-shell", "-p", "python3.withPackages (ps: with ps; [ numpy pillow scikit-learn ])", "--run", f"python3 {' '.join(sys.argv)}"]
    sys.exit(os.system(" ".join(_cmd)))

from classify import get_descriptor_for_path, oklab_to_hex, classify_image_natural
from registry import ThemeRegistry

REGISTRY = ThemeRegistry()


def process_file(file_info, cached_map):
    fname, fpath, mtime, size, is_video, is_gif, folder_hint = file_info
    furl = f"file://{fpath}"

    existing = cached_map.get(fpath)
    if existing and existing.get("mtime") == mtime and existing.get("size") == size and existing.get("band") is not None and existing.get("wallust_v2"):
        return existing

    try:
        raw_theme, hex_color, band, color_key = classify_image_natural(fpath)
        bucket = raw_theme.capitalize()

        # Connect open-set descriptor tracking to discovery pool
        desc = get_descriptor_for_path(fpath)
        if desc is not None:
            reg_res = REGISTRY.classify(desc, update=True)
            if reg_res.get("novel"):
                REGISTRY.add_to_pending(fpath, desc)
    except Exception:
        desc = get_descriptor_for_path(fpath)
        if desc is not None:
            res = REGISTRY.classify(desc, update=False)
            raw_theme = res.get("theme", "Dark")
            bucket = raw_theme.capitalize()
            accent_lab = desc[3:6]
            hex_color = oklab_to_hex(accent_lab)
            chroma = float(math.sqrt(desc[4]**2 + desc[5]**2))
            if chroma < 0.04:
                band = 0
                color_key = float(desc[0] * 100.0)
            else:
                band = 1
                hue_rad = (math.atan2(desc[5], desc[4]) + 2.0 * math.pi) % (2.0 * math.pi)
                color_key = float(hue_rad * (180.0 / math.pi))
        else:
            hex_color = "#1e1e2e"
            bucket = folder_hint.capitalize() if folder_hint else "Dark"
            band = 0
            color_key = 0.0

    return {
        "fileName": fname,
        "filePath": fpath,
        "fileUrl": furl,
        "isVideo": is_video,
        "isGif": is_gif,
        "hex": hex_color,
        "bucket": bucket,
        "theme": bucket.lower(),
        "band": band,
        "colorKey": round(color_key, 2),
        "wallust_v2": True,
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

    img_exts = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
    vid_exts = {".mp4", ".mkv", ".mov", ".webm"}

    entries = []
    src_abs = os.path.abspath(src_dir)
    for root, dirs, files in os.walk(src_dir):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ("previews", "scripts", "flat")]
        rel = os.path.relpath(root, src_abs)
        folder_hint = None
        if rel != "." and "/" not in rel:
            folder_hint = rel.lower()

        for fname in files:
            if fname.startswith("."):
                continue
            ext = os.path.splitext(fname)[1].lower()
            is_gif = ext == ".gif"
            is_video = ext in vid_exts
            if ext not in img_exts and not is_gif and not is_video:
                continue

            fpath = os.path.join(root, fname)
            try:
                st = os.stat(fpath)
                mtime = int(st.st_mtime)
                size = int(st.st_size)
            except Exception:
                continue

            entries.append((fname, fpath, mtime, size, is_video, is_gif, folder_hint))

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
    try:
        REGISTRY.save()
    except Exception:
        pass


if __name__ == "__main__":
    src_dir = os.path.expanduser("~/Pictures/Wallpapers")
    output_file = os.path.expanduser("~/.cache/quickshell/wallpaper_index.json")
    if len(sys.argv) > 1:
        src_dir = os.path.expanduser(sys.argv[1])
    if len(sys.argv) > 2:
        output_file = os.path.expanduser(sys.argv[2])
    run_indexing(src_dir, output_file)
