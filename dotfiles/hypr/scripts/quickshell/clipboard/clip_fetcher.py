#!/usr/bin/env python3
import subprocess
import json
import os
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

def cleanup_cache(all_lines, cache_dir):
    valid_ids = {line.split('\t', 1)[0] for line in all_lines if '\t' in line}
    try:
        for f in os.listdir(cache_dir):
            if f.endswith('.png') and f.replace('.png', '') not in valid_ids:
                os.remove(os.path.join(cache_dir, f))
        except Exception:
            pass

def decode_image(iid, img_path):
    if not os.path.exists(img_path):
        try:
            with open(img_path, "wb") as f:
                subprocess.run(["cliphist", "decode", iid], stdout=f, check=True)
        except Exception:
            pass

def get_cliphist():
    offset = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 12 
    cache_dir = sys.argv[3] if len(sys.argv) > 3 else os.environ.get(
        "QS_CACHE_CLIPBOARD", os.path.expanduser("~/.cache/quickshell/clipboard")
    )
    os.makedirs(cache_dir, exist_ok=True)
    
    try:
        result = subprocess.run(["cliphist", "list"], capture_output=True, text=True, check=True)
        all_lines = [line for line in result.stdout.splitlines() if line]
        lines = all_lines[offset:offset+limit]
        
        if offset == 0:
            threading.Thread(target=cleanup_cache, args=(all_lines, cache_dir), daemon=True).start()
    except Exception:
        print("[]")
        return

    items = []
    image_tasks = []

    for line in lines:
        parts = line.split('\t', 1)
        if len(parts) != 2: 
            continue
        
        iid, content = parts[0], parts[1]
        item_type = "text"
        display_content = content.strip()

        if "[[ binary data" in content:
            item_type = "image"
            img_path = os.path.join(cache_dir, f"{iid}.png")
            display_content = img_path
            image_tasks.append((iid, img_path))

        items.append({
            "id": iid,
            "content": display_content,
            "type": item_type
        })

    if image_tasks:
        with ThreadPoolExecutor(max_workers=min(4, len(image_tasks))) as executor:
            executor.map(lambda task: decode_image(*task), image_tasks)

    print(json.dumps(items))

if __name__ == "__main__":
    get_cliphist()