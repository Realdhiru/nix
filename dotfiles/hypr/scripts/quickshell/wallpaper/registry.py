#!/usr/bin/env python3
"""Theme registry and lifecycle management for open-set wallpaper color classification."""

import os
import sys
import json
import math
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any, Union

# Auto re-exec into Nix environment if needed
try:
    import numpy as np
    from sklearn.cluster import AgglomerativeClustering
except ImportError:
    for _cand in (
        "/nix/store/qswcjhjlrf37snr5dzmcp15zvw74cyxq-python3-3.14.7-env/bin/python3",
    ):
        if os.path.exists(_cand):
            os.execv(_cand, [_cand] + sys.argv)
    _cmd = ["nix-shell", "-p", "python3.withPackages (ps: with ps; [ numpy pillow scikit-learn ])", "--run", f"python3 {' '.join(sys.argv)}"]
    sys.exit(os.system(" ".join(_cmd)))

from classify import (
    CONFIG,
    hex_to_oklab,
    get_descriptor_for_path,
    descriptor_distance,
    load_image_frame,
    extract_descriptor,
)

THEMES_PATH = Path.home() / ".cache" / "quickshell" / "wallpaper_picker" / "themes.json"

SEEDED_THEMES: Dict[str, List[str]] = {
    "gruvbox": ["#d79921", "#fabd2f", "#ebdbb2"],
    "sakura": ["#f38ba8", "#ffb4c6"],
    "nord": ["#88c0d0", "#81a1c1"],
    "ocean": ["#1e66f5", "#74c7ec"],
    "emerald": ["#50fa7b", "#2ee6a8"],
    "sunset": ["#ffb86c", "#ff5555"],
    "synthwave": ["#bd93f9", "#ff79c6"],
    "crimson": ["#e63946", "#d90429"],
    "violet": ["#9d4edd", "#7b2cbf"],
    "monochrome": ["#778899", "#808080"],
    "dark": ["#1e1e2e", "#313244"],
    "light": ["#ffffff", "#cbd5e1"],
}

CSS_COLORS: Dict[str, str] = {
    "aliceblue": "#f0f8ff", "antiquewhite": "#faebd7", "aqua": "#00ffff", "aquamarine": "#7fffd4",
    "azure": "#f0ffff", "beige": "#f5f5dc", "bisque": "#ffe4c4", "black": "#000000",
    "blanchedalmond": "#ffebcd", "blue": "#0000ff", "blueviolet": "#8a2be2", "brown": "#a52a2a",
    "burlywood": "#deb887", "cadetblue": "#5f9ea0", "chartreuse": "#7fff00", "chocolate": "#d2691e",
    "coral": "#ff7f50", "cornflowerblue": "#6495ed", "cornsilk": "#fff8dc", "crimson": "#dc143c",
    "cyan": "#00ffff", "darkblue": "#00008b", "darkcyan": "#008b8b", "darkgoldenrod": "#b8860b",
    "darkgray": "#a9a9a9", "darkgreen": "#006400", "darkkhaki": "#bdb76b", "darkmagenta": "#8b008b",
    "darkolivegreen": "#556b2f", "darkorange": "#ff8c00", "darkorchid": "#9932cc", "darkred": "#8b0000",
    "darksalmon": "#e9967a", "darkseagreen": "#8fbc8f", "darkslateblue": "#483d8b", "darkslategray": "#2f4f4f",
    "darkturquoise": "#00ced1", "darkviolet": "#9400d3", "deeppink": "#ff1493", "deepskyblue": "#00bfff",
    "dimgray": "#696969", "dodgerblue": "#1e90ff", "firebrick": "#b22222", "floralwhite": "#fffaf0",
    "forestgreen": "#228b22", "fuchsia": "#ff00ff", "gainsboro": "#dcdcdc", "ghostwhite": "#f8f8ff",
    "gold": "#ffd700", "goldenrod": "#daa520", "gray": "#808080", "green": "#008000",
    "greenyellow": "#adff2f", "honeydew": "#f0fff0", "hotpink": "#ff69b4", "indianred": "#cd5c5c",
    "indigo": "#4b0082", "ivory": "#fffff0", "khaki": "#f0e68c", "lavender": "#e6e6fa",
    "lavenderblush": "#fff0f5", "lawngreen": "#7cfc00", "lemonchiffon": "#fffacd", "lightblue": "#add8e6",
    "lightcoral": "#f08080", "lightcyan": "#e0ffff", "lightgoldenrodyellow": "#fafad2", "lightgray": "#d3d3d3",
    "lightgreen": "#90ee90", "lightpink": "#ffb6c1", "lightsalmon": "#ffa07a", "lightseagreen": "#20b2aa",
    "lightskyblue": "#87cefa", "lightslategray": "#778899", "lightsteelblue": "#b0c4de", "lightyellow": "#ffffe0",
    "lime": "#00ff00", "limegreen": "#32cd32", "linen": "#faf0e6", "magenta": "#ff00ff",
    "maroon": "#800000", "mediumaquamarine": "#66cdaa", "mediumblue": "#0000cd", "mediumorchid": "#ba55d3",
    "mediumpurple": "#9370db", "mediumseagreen": "#3cb371", "mediumslateblue": "#7b68ee",
    "mediumspringgreen": "#00fa9a", "mediumturquoise": "#48d1cc", "mediumvioletred": "#c71585",
    "midnightblue": "#191970", "mintcream": "#f5fffa", "mistyrose": "#ffe4e1", "moccasin": "#ffe4b5",
    "navajowhite": "#ffdead", "navy": "#000080", "oldlace": "#fdf5e6", "olive": "#808000",
    "olivedrab": "#6b8e23", "orange": "#ffa500", "orangered": "#ff4500", "orchid": "#da70d6",
    "palegoldenrod": "#eee8aa", "palegreen": "#98fb98", "paleturquoise": "#afeeee",
    "palevioletred": "#db7093", "papayawhip": "#ffefd5", "peachpuff": "#ffdab9", "peru": "#cd853f",
    "pink": "#ffc0cb", "plum": "#dda0dd", "powderblue": "#b0e0e6", "purple": "#800080",
    "rebeccapurple": "#663399", "red": "#ff0000", "rosybrown": "#bc8f8f", "royalblue": "#4169e1",
    "saddlebrown": "#8b4513", "salmon": "#fa8072", "sandybrown": "#f4a460", "seagreen": "#2e8b57",
    "seashell": "#fff5ee", "sienna": "#a0522d", "silver": "#c0c0c0", "skyblue": "#87ceeb",
    "slateblue": "#6a5acd", "slategray": "#708090", "snow": "#fffafa", "springgreen": "#00ff7f",
    "steelblue": "#4682b4", "tan": "#d2b48c", "teal": "#008080", "thistle": "#d8bfd8",
    "tomato": "#ff6347", "turquoise": "#40e0d0", "violet": "#ee82ee", "wheat": "#f5deb3",
    "white": "#ffffff", "whitesmoke": "#f5f5f5", "yellow": "#ffff00", "yellowgreen": "#9acd32"
}

_CSS_OKLAB = None


def get_css_oklab_table() -> List[Tuple[str, np.ndarray]]:
    """Return precomputed Oklab (L, a, b) coordinates for all CSS colors."""
    global _CSS_OKLAB
    if _CSS_OKLAB is None:
        _CSS_OKLAB = [(name, hex_to_oklab(hx)) for name, hx in CSS_COLORS.items()]
    return _CSS_OKLAB


def auto_name_color(accent_lab: np.ndarray) -> str:
    """Determine descriptive auto-name for an Oklab color (L, a, b)."""
    table = get_css_oklab_table()
    lab = np.asarray(accent_lab[:3], dtype=np.float64)
    best_name = "neutral"
    best_dist = float("inf")

    for name, c_lab in table:
        d = float(np.linalg.norm(lab - c_lab))
        if d < best_dist:
            best_dist = d
            best_name = name

    L = float(lab[0])
    chroma = float(math.sqrt(lab[1] ** 2 + lab[2] ** 2))

    if chroma < 0.04:
        prefix = "pale" if L > 0.70 else ("dark" if L < 0.35 else "muted")
    else:
        if L < 0.35:
            prefix = "dark"
        elif L > 0.75:
            prefix = "light"
        elif chroma > 0.15:
            prefix = "vivid"
        elif chroma < 0.08:
            prefix = "muted"
        else:
            prefix = ""

    if prefix and not best_name.startswith(prefix):
        return f"{prefix}-{best_name}"
    return best_name


class ThemeRegistry:
    """Manages themes, descriptors, incremental centroid updates, and promotion."""

    def __init__(self, path: Union[str, Path] = THEMES_PATH) -> None:
        self.path = Path(path).resolve()
        self.themes: Dict[str, Dict[str, Any]] = {}
        self.pending: List[Dict[str, Any]] = []
        self.load()

    def load(self) -> None:
        """Load themes and pending pool from themes.json, or seed on first run."""
        if self.path.is_file():
            try:
                with open(self.path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                self.themes = data.get("themes", {})
                self.pending = data.get("pending", [])
                if self.themes:
                    return
            except Exception:
                pass

        self.seed_defaults()

    def save(self) -> None:
        """Persist registry to themes.json atomically."""
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        payload = {
            "version": 1,
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "themes": self.themes,
            "pending": self.pending,
        }
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)
        os.replace(tmp, self.path)

    def seed_defaults(self, wallpaper_dir: Optional[Union[str, Path]] = None) -> None:
        """Seed initial 9 themes from labeled folders or fallback palette hexes."""
        if wallpaper_dir is None:
            default_wp = Path.home() / "Pictures" / "Wallpapers"
            if default_wp.is_dir():
                wallpaper_dir = default_wp

        self.themes = {}
        now_str = datetime.now(timezone.utc).isoformat()

        for key, hex_list in SEEDED_THEMES.items():
            folder_seeded = False
            if wallpaper_dir is not None:
                folder = Path(wallpaper_dir) / key
                if folder.is_dir():
                    images = [
                        p for p in folder.iterdir()
                        if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".mkv", ".webm"}
                    ]
                    descriptors = []
                    paths = []
                    for img in images:
                        desc = get_descriptor_for_path(img)
                        if desc is not None:
                            descriptors.append(desc)
                            paths.append(str(img))
                    if len(descriptors) >= 3:
                        descriptors_np = np.stack(descriptors, axis=0)
                        centroid = np.mean(descriptors_np, axis=0)
                        dists = [descriptor_distance(d, centroid) for d in descriptors_np]
                        radius = max(CONFIG["min_radius"], float(np.mean(dists) + 2.0 * np.std(dists)))
                        self.themes[key] = {
                            "id": key,
                            "name": key,
                            "centroid": centroid.tolist(),
                            "original_centroid": centroid.tolist(),
                            "radius": radius,
                            "count": len(descriptors),
                            "seeded": True,
                            "members": paths,
                            "member_dists": dists[-200:],
                            "last_used": now_str,
                        }
                        folder_seeded = True

            if not folder_seeded:
                pal_lab = [hex_to_oklab(h) for h in hex_list]
                mean_lab = np.mean(pal_lab, axis=0)
                chromas = [math.sqrt(c[1] ** 2 + c[2] ** 2) for c in pal_lab]
                accent_idx = int(np.argmax(chromas))
                accent_lab = pal_lab[accent_idx]
                mean_c = float(np.mean(chromas))

                centroid = np.array([
                    mean_lab[0], mean_lab[1], mean_lab[2],
                    accent_lab[0], accent_lab[1], accent_lab[2],
                    mean_c
                ], dtype=np.float64)

                self.themes[key] = {
                    "id": key,
                    "name": key,
                    "centroid": centroid.tolist(),
                    "original_centroid": centroid.tolist(),
                    "radius": float(CONFIG.get("min_radius", 0.15)),
                    "count": 0,
                    "seeded": True,
                    "members": [],
                    "member_dists": [],
                    "last_used": now_str,
                }

        self.save()

    def classify(
        self,
        path_or_desc: Union[str, Path, np.ndarray],
        update: bool = True
    ) -> Dict[str, Any]:
        """Classify descriptor against registered themes with acceptance gating."""
        path_str = ""
        if isinstance(path_or_desc, (str, Path)):
            path_str = str(Path(path_or_desc).resolve())
            desc = get_descriptor_for_path(path_str)
            if desc is None:
                return {"status": "error", "error": "Failed to extract descriptor", "novel": True}
        else:
            desc = np.asarray(path_or_desc, dtype=np.float64)

        theme_items = list(self.themes.items())
        if not theme_items:
            return {"status": "error", "error": "Registry is empty", "novel": True}

        distances: List[float] = []
        names: List[str] = []
        keys: List[str] = []

        for key, th in theme_items:
            centroid = np.asarray(th["centroid"], dtype=np.float64)
            d = descriptor_distance(desc, centroid)
            distances.append(d)
            names.append(th["name"])
            keys.append(key)

        best_idx = int(np.argmin(distances))
        best_dist = distances[best_idx]
        best_key = keys[best_idx]
        best_theme = self.themes[best_key]

        T = float(CONFIG["T"])
        logits = -np.asarray(distances, dtype=np.float64) / max(T, 1e-4)
        exp_logits = np.exp(logits - np.max(logits))
        probs = exp_logits / np.sum(exp_logits)

        sorted_indices = np.argsort(distances)
        top3 = [
            {
                "theme": names[idx],
                "confidence": float(probs[idx]),
                "distance": float(distances[idx])
            }
            for idx in sorted_indices[:3]
        ]

        threshold = best_theme["radius"] * float(CONFIG["accept"])
        accepted = best_dist <= threshold
        now_str = datetime.now(timezone.utc).isoformat()

        if accepted:
            if update:
                count = best_theme.get("count", 0)
                n = min(count, 200)
                cur_centroid = np.asarray(best_theme["centroid"], dtype=np.float64)
                new_centroid = (cur_centroid * n + desc) / (n + 1.0)

                if best_theme.get("seeded", False) and "original_centroid" in best_theme:
                    orig_centroid = np.asarray(best_theme["original_centroid"], dtype=np.float64)
                    drift = descriptor_distance(new_centroid, orig_centroid)
                    max_drift = float(CONFIG["max_seed_drift"])
                    if drift > max_drift and drift > 1e-6:
                        direction = (new_centroid - orig_centroid) / drift
                        new_centroid = orig_centroid + direction * max_drift

                best_theme["centroid"] = new_centroid.tolist()
                best_theme["count"] = count + 1
                best_theme["last_used"] = now_str

                member_dists = best_theme.get("member_dists", [])
                member_dists.append(best_dist)
                if len(member_dists) > 200:
                    member_dists = member_dists[-200:]
                best_theme["member_dists"] = member_dists

                if len(member_dists) >= 3:
                    new_radius = float(np.mean(member_dists) + 2.0 * np.std(member_dists))
                    best_theme["radius"] = max(CONFIG["min_radius"], new_radius)

                if path_str:
                    members = best_theme.setdefault("members", [])
                    if path_str not in members:
                        members.append(path_str)

            return {
                "status": "assigned",
                "theme": best_theme["name"],
                "theme_id": best_theme["id"],
                "confidence": float(probs[best_idx]),
                "distance": best_dist,
                "top3": top3,
                "novel": False
            }
        else:
            if path_str:
                self.add_to_pending(path_str, desc)

            return {
                "status": "novel",
                "theme": best_theme["name"],
                "theme_id": best_theme["id"],
                "confidence": float(probs[best_idx]),
                "distance": best_dist,
                "top3": top3,
                "novel": True
            }

    def add_to_pending(self, path: str, descriptor: np.ndarray) -> None:
        """Add image to pending novel pool if not already queued."""
        for item in self.pending:
            if item.get("path") == path:
                item["descriptor"] = descriptor.tolist()
                return
        self.pending.append({
            "path": path,
            "descriptor": descriptor.tolist(),
            "added_at": datetime.now(timezone.utc).isoformat()
        })

    def promote(self) -> List[Dict[str, Any]]:
        """Cluster pending pool and promote qualifying groups to new themes."""
        min_members = int(CONFIG["min_members"])
        if len(self.pending) < min_members:
            return []

        descriptors = [np.asarray(item["descriptor"], dtype=np.float64) for item in self.pending]
        X = np.stack(descriptors, axis=0)

        clustering = AgglomerativeClustering(
            n_clusters=None,
            distance_threshold=float(CONFIG["new_theme_dist"]),
            metric="euclidean",
            linkage="average"
        )
        labels = clustering.fit_predict(X)

        new_themes_created = []
        promoted_indices = set()
        existing_names = {th["name"].lower() for th in self.themes.values()}

        for label in set(labels):
            idxs = np.where(labels == label)[0]
            if len(idxs) < min_members:
                continue

            cluster_X = X[idxs]
            centroid = np.mean(cluster_X, axis=0)
            dists = [descriptor_distance(x, centroid) for x in cluster_X]
            mean_intra = float(np.mean(dists))

            if mean_intra < float(CONFIG["max_spread"]):
                radius = max(CONFIG["min_radius"], float(mean_intra + 2.0 * np.std(dists)))
                accent_lab = centroid[3:6]
                base_name = auto_name_color(accent_lab)

                final_name = base_name
                counter = 2
                while final_name.lower() in existing_names:
                    final_name = f"{base_name}-{counter}"
                    counter += 1
                existing_names.add(final_name.lower())

                theme_id = f"theme_{uuid.uuid4().hex[:8]}"
                member_paths = [self.pending[i]["path"] for i in idxs]

                new_theme = {
                    "id": theme_id,
                    "name": final_name,
                    "centroid": centroid.tolist(),
                    "original_centroid": centroid.tolist(),
                    "radius": radius,
                    "count": len(idxs),
                    "seeded": False,
                    "members": member_paths,
                    "member_dists": dists,
                    "last_used": datetime.now(timezone.utc).isoformat(),
                }

                self.themes[theme_id] = new_theme
                new_themes_created.append(new_theme)
                promoted_indices.update(idxs.tolist())

        if promoted_indices:
            self.pending = [
                item for i, item in enumerate(self.pending)
                if i not in promoted_indices
            ]
            self.save()

        return new_themes_created

    def merge(self) -> List[Tuple[str, str]]:
        """Merge any two themes whose centroid distance is within merge_dist."""
        merge_dist = float(CONFIG["merge_dist"])
        merged_pairs = []
        keys = list(self.themes.keys())

        i = 0
        while i < len(keys):
            key_a = keys[i]
            if key_a not in self.themes:
                i += 1
                continue
            th_a = self.themes[key_a]
            c_a = np.asarray(th_a["centroid"], dtype=np.float64)

            j = i + 1
            while j < len(keys):
                key_b = keys[j]
                if key_b not in self.themes:
                    j += 1
                    continue
                th_b = self.themes[key_b]
                c_b = np.asarray(th_b["centroid"], dtype=np.float64)

                d = descriptor_distance(c_a, c_b)
                if d < merge_dist:
                    if th_a.get("seeded", False) and not th_b.get("seeded", False):
                        winner_key, loser_key = key_a, key_b
                    elif th_b.get("seeded", False) and not th_a.get("seeded", False):
                        winner_key, loser_key = key_b, key_a
                    elif th_a.get("count", 0) >= th_b.get("count", 0):
                        winner_key, loser_key = key_a, key_b
                    else:
                        winner_key, loser_key = key_b, key_a

                    winner = self.themes[winner_key]
                    loser = self.themes[loser_key]

                    c_win = np.asarray(winner["centroid"], dtype=np.float64)
                    c_lose = np.asarray(loser["centroid"], dtype=np.float64)
                    cnt_win = winner.get("count", 0)
                    cnt_lose = loser.get("count", 0)
                    total_cnt = max(cnt_win + cnt_lose, 1)

                    merged_c = (c_win * cnt_win + c_lose * cnt_lose) / total_cnt
                    winner["centroid"] = merged_c.tolist()
                    winner["count"] = total_cnt
                    winner["radius"] = max(winner["radius"], loser["radius"])
                    winner["members"] = list(set(winner.get("members", []) + loser.get("members", [])))
                    winner["member_dists"] = (winner.get("member_dists", []) + loser.get("member_dists", []))[-200:]

                    merged_pairs.append((winner["name"], loser["name"]))
                    del self.themes[loser_key]

                    keys = list(self.themes.keys())
                    c_a = np.asarray(self.themes[key_a]["centroid"], dtype=np.float64) if key_a in self.themes else None
                    if c_a is None:
                        break
                j += 1
            i += 1

        if merged_pairs:
            self.save()
        return merged_pairs

    def prune(self) -> List[str]:
        """Delete non-seeded themes with count < 3 older than stale_days."""
        stale_days = float(CONFIG["stale_days"])
        now = datetime.now(timezone.utc)
        pruned_ids = []

        for key, th in list(self.themes.items()):
            if th.get("seeded", False):
                continue
            if th.get("count", 0) < 3:
                last_used_str = th.get("last_used")
                is_stale = False
                if last_used_str:
                    try:
                        last_used = datetime.fromisoformat(last_used_str)
                        if (now - last_used).total_seconds() > stale_days * 86400:
                            is_stale = True
                    except Exception:
                        is_stale = True
                else:
                    is_stale = True

                if is_stale:
                    for p in th.get("members", []):
                        desc = get_descriptor_for_path(p)
                        if desc is not None:
                            self.add_to_pending(p, desc)
                    pruned_ids.append(th["name"])
                    del self.themes[key]

        if pruned_ids:
            self.save()
        return pruned_ids

    def reassign_all(self, file_paths: Optional[List[str]] = None) -> Dict[str, int]:
        """Re-run classification across all registered themes."""
        paths_to_classify = []
        if file_paths is not None:
            paths_to_classify = file_paths
        else:
            for th in self.themes.values():
                paths_to_classify.extend(th.get("members", []))
            for item in self.pending:
                paths_to_classify.append(item["path"])
            paths_to_classify = list(set(paths_to_classify))

        for th in self.themes.values():
            th["members"] = []
            th["member_dists"] = []
            th["count"] = 0
        self.pending = []

        counts: Dict[str, int] = {th["name"]: 0 for th in self.themes.values()}
        counts["pending"] = 0

        for p in paths_to_classify:
            res = self.classify(p, update=True)
            if res.get("status") == "assigned":
                counts[res["theme"]] = counts.get(res["theme"], 0) + 1
            else:
                counts["pending"] += 1

        self.save()
        return counts

    def rename_theme(self, identifier: str, new_name: str) -> bool:
        """Rename a theme by id or current name."""
        target_key = None
        for key, th in self.themes.items():
            if th["id"] == identifier or th["name"].lower() == identifier.lower():
                target_key = key
                break
        if target_key is None:
            return False

        self.themes[target_key]["name"] = new_name.strip()
        self.save()
        return True
