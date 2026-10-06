#!/usr/bin/env python3
"""Color sorting via nearest-neighbor + 2-opt shortest open path in Oklab space."""

import os
import sys
import math
from pathlib import Path
from typing import List, Dict, Any, Union, Optional, Tuple

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

from classify import get_descriptor_for_path
from registry import ThemeRegistry


def extract_sort_feature(descriptor: np.ndarray) -> np.ndarray:
    """Extract 6D sort feature: top-3 weighted mean (L, a, b) + 0.5 * accent (L, a, b)."""
    desc = np.asarray(descriptor, dtype=np.float64)
    return np.array([
        desc[0], desc[1], desc[2],
        0.5 * desc[3], 0.5 * desc[4], 0.5 * desc[5]
    ], dtype=np.float64)


def sort_wallpapers(
    paths: List[Union[str, Path]],
    max_2opt_iters: int = 100
) -> List[str]:
    """Sort wallpaper paths along shortest open path in color space starting at darkest."""
    valid_paths: List[str] = []
    features: List[np.ndarray] = []
    lightnesses: List[float] = []

    for p in paths:
        p_str = str(Path(p).resolve())
        desc = get_descriptor_for_path(p_str)
        if desc is not None:
            valid_paths.append(p_str)
            feat = extract_sort_feature(desc)
            features.append(feat)
            lightnesses.append(float(feat[0]))

    n = len(valid_paths)
    if n <= 1:
        return valid_paths

    F = np.stack(features, axis=0)  # Shape (N, 6)

    # Start at darkest image (minimum L)
    start_idx = int(np.argmin(lightnesses))

    # 1. Nearest-Neighbor greedy open path
    unvisited = set(range(n))
    unvisited.remove(start_idx)
    path = [start_idx]

    current = start_idx
    while unvisited:
        rem_indices = list(unvisited)
        diffs = F[rem_indices] - F[current]
        dists = np.sum(diffs ** 2, axis=1)
        next_idx = rem_indices[int(np.argmin(dists))]
        path.append(next_idx)
        unvisited.remove(next_idx)
        current = next_idx

    # Precompute pairwise distance matrix for 2-opt
    diff = F[:, np.newaxis, :] - F[np.newaxis, :, :]
    dist_mat = np.sqrt(np.sum(diff ** 2, axis=-1))

    # 2. 2-Opt local search refinement (start node fixed at darkest)
    improved = True
    iterations = 0
    while improved and iterations < max_2opt_iters:
        improved = False
        iterations += 1
        for i in range(1, n - 1):
            for j in range(i + 1, n):
                prev_i = path[i - 1]
                curr_i = path[i]
                curr_j = path[j]
                next_j = path[j + 1] if j + 1 < n else None

                current_cost = dist_mat[prev_i, curr_i]
                if next_j is not None:
                    current_cost += dist_mat[curr_j, next_j]

                new_cost = dist_mat[prev_i, curr_j]
                if next_j is not None:
                    new_cost += dist_mat[curr_i, next_j]

                if new_cost < current_cost - 1e-7:
                    path[i:j + 1] = path[i:j + 1][::-1]
                    improved = True

    return [valid_paths[idx] for idx in path]


def get_theme_display_order(registry: ThemeRegistry) -> List[Dict[str, Any]]:
    """Sort themes by centroid hue, placing achromatic themes first sorted by L."""
    achromatic = []
    chromatic = []

    for key, th in registry.themes.items():
        centroid = np.asarray(th["centroid"], dtype=np.float64)
        L = float(centroid[0])
        a = float(centroid[1])
        b = float(centroid[2])
        chroma = float(math.sqrt(a ** 2 + b ** 2))
        hue = (math.atan2(b, a) + 2.0 * math.pi) % (2.0 * math.pi)

        item = {
            "id": th["id"],
            "name": th["name"],
            "count": th.get("count", 0),
            "seeded": th.get("seeded", False),
            "L": L,
            "chroma": chroma,
            "hue": hue,
        }

        if chroma < 0.04:
            achromatic.append(item)
        else:
            chromatic.append(item)

    # Achromatic themes ordered by lightness L
    achromatic.sort(key=lambda x: x["L"])
    # Chromatic themes ordered by hue angle
    chromatic.sort(key=lambda x: x["hue"])

    return achromatic + chromatic


if __name__ == "__main__":
    if len(sys.argv) > 1:
        target_dir = Path(sys.argv[1]).resolve()
        if target_dir.is_dir():
            files = [
                p for p in target_dir.iterdir()
                if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".mkv", ".webm"}
            ]
            ordered = sort_wallpapers(files)
            print(f"Sorted {len(ordered)} files:")
            for p in ordered[:10]:
                print(f"  {Path(p).name}")
            if len(ordered) > 10:
                print(f"  ... and {len(ordered) - 10} more")
    else:
        reg = ThemeRegistry()
        order = get_theme_display_order(reg)
        print("Theme display order:")
        for t in order:
            print(f"  - {t['name']} (L={t['L']:.2f}, C={t['chroma']:.2f}, H={t['hue']:.2f})")
