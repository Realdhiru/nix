#!/usr/bin/env python3
import subprocess
import json
import os
import sys
import threading
import concurrent.futures

def cleanup_cache(all_lines, cache_dir):
    valid_ids = set()
    # Keep top 100 recent IDs to prevent infinite cache bloat
    for line in all_lines[:100]:
        if '\t' in line:
            valid_ids.add(line.split('\t', 1)[0])
    try:
        for f in os.listdir(cache_dir):
            if f.endswith('.png'):
                iid = f.replace('.png', '')
                if iid not in valid_ids:
                    try:
                        os.remove(os.path.join(cache_dir, f))
                    except Exception:
                        pass
    except Exception:
        pass

def decode_image(iid, img_path):
    if not os.path.exists(img_path):
        with open(img_path, "wb") as f:
            subprocess.run(["cliphist", "decode", iid], stdout=f)
    return {
        "id": iid,
        "content": img_path,
        "type": "image"
    }

def get_cliphist():
    # Implement pagination arguments
    offset = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    # Slightly smaller limit to make the initial UI pop open faster
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 12

    # Use dynamically provided cache dir from QML or fallback securely
    cache_dir = sys.argv[3] if len(sys.argv) > 3 else os.environ.get("QS_CACHE_CLIPBOARD", os.path.expanduser("~/.cache/quickshell/clipboard"))
    os.makedirs(cache_dir, exist_ok=True)

    try:
        # Fetch the entire list quickly
        result = subprocess.run(["cliphist", "list"], capture_output=True, text=True)
        all_lines = result.stdout.strip().split('\n')
        # Slice only the requested chunk
        lines = all_lines[offset:offset+limit]
        
        # Move cleanup to a background thread so it doesn't block the UI from receiving data
        if offset == 0:
            threading.Thread(target=cleanup_cache, args=(all_lines, cache_dir), daemon=True).start()
    except Exception as e:
        print("[]")
        return

    # Dictionary mapping to ensure threaded operations are rebuilt in exact chronological order
    items_map = {}
    image_tasks = []
    
    with concurrent.futures.ThreadPoolExecutor() as executor:
        for idx, line in enumerate(lines):
            if not line: continue
            parts = line.split('\t', 1)
            if len(parts) != 2: continue
            
            iid, content = parts[0], parts[1]
            display_content = content.strip()

            # Detect images in cliphist output
            if "[[ binary data" in content:
                img_path = os.path.join(cache_dir, f"{iid}.png")
                # CACHING: Only decode the specific item if it doesn't already exist
                future = executor.submit(decode_image, iid, img_path)
                image_tasks.append((idx, future))
            else:
                items_map[idx] = {
                    "id": iid,
                    "content": display_content,
                    "type": "text"
                }
                
        for idx, future in image_tasks:
            items_map[idx] = future.result()

    # Reconstruct the final list maintaining the original chronological order
    ordered_items = [items_map[idx] for idx in sorted(items_map.keys())]
        
    print(json.dumps(ordered_items))

if __name__ == "__main__":
    get_cliphist()