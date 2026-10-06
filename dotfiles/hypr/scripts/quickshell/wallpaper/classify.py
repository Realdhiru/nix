#!/usr/bin/env python3
"""Open-set wallpaper color extraction and descriptor calculation in Oklab space."""

import os
import sys
import json
import sqlite3
import subprocess
from pathlib import Path
from typing import Tuple, List, Optional, Union, Dict, Any

# Re-exec under environment with numpy/scipy/sklearn if needed
try:
    import numpy as np
    from PIL import Image
    from sklearn.cluster import KMeans
    import warnings
    from sklearn.exceptions import ConvergenceWarning
    warnings.filterwarnings("ignore", category=ConvergenceWarning)
except ImportError:
    for _cand in (
        "/nix/store/qswcjhjlrf37snr5dzmcp15zvw74cyxq-python3-3.14.7-env/bin/python3",
    ):
        if os.path.exists(_cand):
            os.execv(_cand, [_cand] + sys.argv)
    _cmd = ["nix-shell", "-p", "python3.withPackages (ps: with ps; [ numpy pillow scikit-learn ])", "--run", f"python3 {' '.join(sys.argv)}"]
    sys.exit(subprocess.call(_cmd))

CONFIG: Dict[str, Any] = {
    "k": 6,
    "n_init": 3,
    "gamma": 1.5,
    "accent_bonus": 2.0,
    "descriptor_weights": [1.5, 2.5, 2.5, 0.6, 0.6, 0.6, 1.0],
    "accept": 1.0,
    "T": 0.15,
    "min_radius": 0.12,
    "max_seed_drift": 0.08,
    "new_theme_dist": 0.22,
    "min_members": 5,
    "max_spread": 0.18,
    "merge_dist": 0.10,
    "stale_days": 14,
}

DB_PATH = Path.home() / ".cache" / "quickshell" / "wallpaper_picker" / "descriptors.db"


def srgb_to_linear(rgb: np.ndarray) -> np.ndarray:
    """Vectorized conversion from sRGB [0, 1] to linear RGB."""
    mask = rgb > 0.04045
    linear = np.empty_like(rgb, dtype=np.float64)
    linear[mask] = ((rgb[mask] + 0.055) / 1.055) ** 2.4
    linear[~mask] = rgb[~mask] / 12.92
    return linear


def linear_to_oklab(linear_rgb: np.ndarray) -> np.ndarray:
    """Vectorized conversion from linear RGB to Ottosson's Oklab (L, a, b)."""
    r = linear_rgb[..., 0]
    g = linear_rgb[..., 1]
    b = linear_rgb[..., 2]

    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

    l_ = np.cbrt(np.maximum(l, 0.0))
    m_ = np.cbrt(np.maximum(m, 0.0))
    s_ = np.cbrt(np.maximum(s, 0.0))

    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

    return np.stack([L, a, b], axis=-1)


def hex_to_oklab(hex_str: str) -> np.ndarray:
    """Convert a single hex color string to Oklab coordinates."""
    hex_str = hex_str.strip().lstrip("#")
    if len(hex_str) == 3:
        hex_str = "".join(c * 2 for c in hex_str)
    r = int(hex_str[0:2], 16) / 255.0
    g = int(hex_str[2:4], 16) / 255.0
    b = int(hex_str[4:6], 16) / 255.0
    rgb = np.array([[[r, g, b]]], dtype=np.float64)
    return linear_to_oklab(srgb_to_linear(rgb))[0, 0]


def oklab_to_hex(lab: np.ndarray) -> str:
    """Convert Oklab (L, a, b) coordinates to standard sRGB hex string."""
    L, a, b = float(lab[0]), float(lab[1]), float(lab[2])
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l = l_ ** 3
    m = m_ ** 3
    s = s_ ** 3
    r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    rgb = np.array([r, g, b], dtype=np.float64)
    rgb = np.clip(rgb, 0.0, 1.0)
    mask = rgb > 0.0031308
    srgb = np.empty_like(rgb)
    srgb[mask] = 1.055 * (rgb[mask] ** (1.0 / 2.4)) - 0.055
    srgb[~mask] = 12.92 * rgb[~mask]
    srgb_int = np.clip(np.round(srgb * 255.0), 0, 255).astype(int)
    return f"#{srgb_int[0]:02x}{srgb_int[1]:02x}{srgb_int[2]:02x}"


def load_image_frame(path: Union[str, Path]) -> Optional[Image.Image]:
    """Load first frame of static image, GIF, or video resized to 64x64 BOX."""
    path = Path(path)
    if not path.exists():
        return None

    ext = path.suffix.lower()
    vid_exts = {".mp4", ".mkv", ".mov", ".webm"}

    if ext in vid_exts:
        try:
            cmd = ["ffmpeg", "-ss", "00:00:01", "-i", str(path), "-vframes", "1", "-f", "image2pipe", "-vcodec", "png", "-"]
            proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=5)
            if proc.returncode != 0 or not proc.stdout:
                cmd = ["ffmpeg", "-ss", "00:00:00", "-i", str(path), "-vframes", "1", "-f", "image2pipe", "-vcodec", "png", "-"]
                proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=5)
            if proc.returncode == 0 and proc.stdout:
                import io
                im = Image.open(io.BytesIO(proc.stdout))
                return im.convert("RGB").resize((64, 64), Image.Resampling.BOX)
        except Exception:
            return None

    try:
        im = Image.open(path)
        if ext in {".jpg", ".jpeg"}:
            im.draft("RGB", (64, 64))
        if getattr(im, "is_animated", False):
            im.seek(0)
        im = im.convert("RGB")
        return im.resize((64, 64), Image.Resampling.BOX)
    except Exception:
        return None


def extract_descriptor(image: Image.Image) -> np.ndarray:
    """Compute holistic 7D Oklab descriptor vector representing whole-image color mass."""
    arr = np.asarray(image, dtype=np.float64) / 255.0
    pixels_oklab = linear_to_oklab(srgb_to_linear(arr)).reshape(-1, 3)

    L_all = pixels_oklab[:, 0]
    a_all = pixels_oklab[:, 1]
    b_all = pixels_oklab[:, 2]
    chromas_all = np.sqrt(a_all ** 2 + b_all ** 2)

    mL = float(np.mean(L_all))
    ma = float(np.mean(a_all))
    mb = float(np.mean(b_all))
    mC = float(np.mean(chromas_all))

    # KMeans on pixel clusters for major color blocks
    k = min(4, CONFIG.get("k", 4))
    kmeans = KMeans(
        n_clusters=k,
        n_init=CONFIG["n_init"],
        random_state=42
    )
    labels = kmeans.fit_predict(pixels_oklab)
    centers = kmeans.cluster_centers_

    counts = np.bincount(labels, minlength=k).astype(np.float64)
    areas = counts / float(len(labels))

    c_centers = np.sqrt(centers[:, 1] ** 2 + centers[:, 2] ** 2)
    # Balanced weighting: areas retain primary authority, with moderate chroma consideration
    weights = areas * (1.0 + np.minimum(c_centers, 0.25) * 1.5)
    best_idx = int(np.argmax(weights))
    prominent_block = centers[best_idx]

    descriptor = np.array([
        mL, ma, mb,
        prominent_block[0], prominent_block[1], prominent_block[2],
        mC
    ], dtype=np.float64)

    return descriptor


def descriptor_distance(u: np.ndarray, v: np.ndarray, weights: Optional[List[float]] = None) -> float:
    """Calculate weighted Euclidean distance between two 7D Oklab descriptors."""
    if weights is None:
        weights = CONFIG["descriptor_weights"]
    w = np.asarray(weights, dtype=np.float64)
    diff = np.asarray(u, dtype=np.float64) - np.asarray(v, dtype=np.float64)
    return float(np.sqrt(np.sum(w * (diff ** 2))))


def init_db() -> sqlite3.Connection:
    """Initialize SQLite descriptor cache database."""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.execute(
        "CREATE TABLE IF NOT EXISTS descriptors ("
        "path TEXT PRIMARY KEY, mtime REAL, descriptor TEXT"
        ")"
    )
    conn.commit()
    return conn


def get_descriptor_for_path(path: Union[str, Path], conn: Optional[sqlite3.Connection] = None) -> Optional[np.ndarray]:
    """Retrieve descriptor from cache if mtime matches, or compute and store."""
    p = Path(path).resolve()
    if not p.is_file():
        return None

    try:
        mtime = p.stat().st_mtime
    except OSError:
        return None

    close_conn = False
    if conn is None:
        conn = init_db()
        close_conn = True

    cur = conn.cursor()
    cur.execute("SELECT mtime, descriptor FROM descriptors WHERE path = ?", (str(p),))
    row = cur.fetchone()

    if row is not None and abs(row[0] - mtime) < 1e-4:
        desc = np.array(json.loads(row[1]), dtype=np.float64)
        if close_conn:
            conn.close()
        return desc

    image = load_image_frame(p)
    if image is None:
        if close_conn:
            conn.close()
        return None

    desc = extract_descriptor(image)
    cur.execute(
        "INSERT OR REPLACE INTO descriptors (path, mtime, descriptor) VALUES (?, ?, ?)",
        (str(p), mtime, json.dumps(desc.tolist()))
    )
    conn.commit()

    if close_conn:
        conn.close()

    return desc


def classify_image_natural(path_or_image: Union[str, Path, Image.Image]) -> Tuple[str, str, int, float]:
    """
    Classify wallpaper according to its whole-image color mass without accent distortion.
    Returns: (theme_name, hex_color, band, color_key)
    """
    if isinstance(path_or_image, (str, Path)):
        im = load_image_frame(path_or_image)
        if im is None:
            return "dark", "#1e1e2e", 0, 0.0
    else:
        im = path_or_image

    arr = np.asarray(im.resize((48, 48)), dtype=np.float64) / 255.0
    pixels = linear_to_oklab(srgb_to_linear(arr)).reshape(-1, 3)

    L = pixels[:, 0]
    a = pixels[:, 1]
    b = pixels[:, 2]
    chromas = np.sqrt(a ** 2 + b ** 2)

    mL = float(np.mean(L))
    dark_ratio = float(np.mean(L < 0.24))
    light_ratio = float(np.mean(L > 0.74))
    ma = float(np.mean(a))
    mb = float(np.mean(b))
    mC = float(np.mean(chromas))

    accent_idx = int(np.argmax(chromas))
    rep_hex = oklab_to_hex(pixels[accent_idx]) if mC >= 0.03 else ("#1e1e2e" if mL < 0.3 else "#f5f5f5")
    neon_accents = float(np.mean((chromas > 0.12) & ((a > 0.04) | (b < -0.04))))

    if dark_ratio >= 0.50 or (mL < 0.23 and dark_ratio >= 0.35):
        if neon_accents >= 0.10:
            return "synthwave", rep_hex, 1, 300.0
        return "dark", "#1e1e2e", 0, round(mL * 100.0, 2)
    if light_ratio >= 0.45 or (mL > 0.75 and light_ratio >= 0.30):
        return "light", "#f5f5f5", 0, round(mL * 100.0, 2)

    if mC < 0.026:
        return "monochrome", "#778899", 0, round(mL * 100.0, 2)

    hue = float((np.arctan2(mb, ma) * 180.0 / np.pi + 360.0) % 360.0)

    if 100.0 <= hue < 170.0:
        theme = "emerald"
    elif 170.0 <= hue < 255.0:
        theme = "nord" if (mC < 0.052 or ma < -0.015) else "ocean"
    elif 255.0 <= hue < 285.0:
        theme = "ocean"
    elif 285.0 <= hue < 320.0:
        theme = "synthwave" if (mC > 0.08 or neon_accents > 0.08) else "violet"
    elif 320.0 <= hue < 355.0:
        theme = "sakura"
    elif (hue >= 355.0) or (0.0 <= hue < 20.0):
        theme = "crimson" if (ma > 0.04 and mb < 0.02) else "sunset"
    elif 20.0 <= hue < 55.0:
        theme = "sunset" if mC > 0.055 else "gruvbox"
    else:
        theme = "gruvbox"

    return theme, rep_hex, 1, round(hue, 2)
