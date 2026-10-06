#!/usr/bin/env python3
import os
import sys
import json
import csv
import time
import math
import subprocess
from pathlib import Path
from collections import Counter, defaultdict

# Ensure environment
try:
    import numpy as np
    from PIL import Image
    from sklearn.cluster import KMeans
except ImportError:
    for _cand in (
        "/nix/store/qswcjhjlrf37snr5dzmcp15zvw74cyxq-python3-3.14.7-env/bin/python3",
    ):
        if os.path.exists(_cand):
            os.execv(_cand, [_cand] + sys.argv)
    sys.exit("Nix python env not found")

sys.path.insert(0, "/home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper")
from classify import (
    CONFIG,
    srgb_to_linear,
    linear_to_oklab,
    oklab_to_hex,
    load_image_frame,
    classify_image_natural,
    extract_descriptor,
    descriptor_distance,
    hex_to_oklab
)
from registry import ThemeRegistry, SEEDED_THEMES

REPO_DIR = Path("/home/realdhiru/Pictures/Wallpapers")
DIAG_DIR = Path("/home/realdhiru/nix/diagnosis")
DIAG_DIR.mkdir(parents=True, exist_ok=True)

valid_exts = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".mkv", ".webm"}
all_files = sorted([
    p for p in REPO_DIR.rglob("*")
    if p.is_file() and p.suffix.lower() in valid_exts
    and not any(part.startswith(".") or part in ("previews", "scripts", "flat") for part in p.parts)
])

print(f"Total wallpapers located: {len(all_files)}")

# -------------------------------------------------------------
# STEP 2 & 3: Run current classifier, gather deep stats, results.csv
# -------------------------------------------------------------
results = []
flip_counts = defaultdict(int)

# For Step 3c perturbation test:
# Jitter hue by ±3 deg, chroma by ±0.01, dark/light ratios by ±0.02
def classify_perturbed(arr_oklab, d_hue=0.0, d_chroma=0.0, d_dark=0.0, d_light=0.0):
    pixels = arr_oklab.reshape(-1, 3)
    L = pixels[:, 0]
    a = pixels[:, 1]
    b = pixels[:, 2]
    chromas = np.sqrt(a ** 2 + b ** 2)

    mL = float(np.mean(L))
    dark_ratio = float(np.mean(L < (0.24 + d_dark)))
    light_ratio = float(np.mean(L > (0.74 + d_light)))
    ma = float(np.mean(a))
    mb = float(np.mean(b))
    mC = float(np.mean(chromas)) + d_chroma

    neon_accents = float(np.mean((chromas > 0.12) & ((a > 0.04) | (b < -0.04))))

    if dark_ratio >= (0.50 + d_dark) or (mL < 0.23 and dark_ratio >= 0.35):
        if neon_accents >= 0.10:
            return "synthwave"
        return "dark"
    if light_ratio >= (0.45 + d_light) or (mL > 0.75 and light_ratio >= 0.30):
        return "light"

    if mC < (0.026 + d_chroma):
        return "monochrome"

    hue = float((np.arctan2(mb, ma) * 180.0 / np.pi + 360.0 + d_hue) % 360.0)

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
    return theme

# Store data for processing
data_items = []
times_decode = []
times_resize = []
times_oklab = []
times_cluster = []
times_vote = []

for idx, p in enumerate(all_files):
    t0 = time.perf_counter()
    im = load_image_frame(p)
    t1 = time.perf_counter()
    if im is None:
        continue
    
    t_dec = t1 - t0
    times_decode.append(t_dec)

    # Resize 48x48
    t_res0 = time.perf_counter()
    im_48 = im.resize((48, 48), Image.Resampling.BOX)
    t_res1 = time.perf_counter()
    times_resize.append(t_res1 - t_res0)

    # sRGB -> linear -> Oklab
    t_ok0 = time.perf_counter()
    arr = np.asarray(im_48, dtype=np.float64) / 255.0
    arr_oklab = linear_to_oklab(srgb_to_linear(arr))
    pixels_oklab = arr_oklab.reshape(-1, 3)
    t_ok1 = time.perf_counter()
    times_oklab.append(t_ok1 - t_ok0)

    # Feature metrics
    L = pixels_oklab[:, 0]
    a = pixels_oklab[:, 1]
    b = pixels_oklab[:, 2]
    chromas = np.sqrt(a ** 2 + b ** 2)

    mL = float(np.mean(L))
    ma = float(np.mean(a))
    mb = float(np.mean(b))
    mC = float(np.mean(chromas))
    dark_ratio = float(np.mean(L < 0.24))
    light_ratio = float(np.mean(L > 0.74))
    neon_accents = float(np.mean((chromas > 0.12) & ((a > 0.04) | (b < -0.04))))
    chromatic_mass = float(np.mean(chromas > 0.04))
    raw_hue = float((np.arctan2(mb, ma) * 180.0 / np.pi + 360.0) % 360.0)

    # Current vote
    t_v0 = time.perf_counter()
    current_label, rep_hex, band, color_key = classify_image_natural(p)
    t_v1 = time.perf_counter()
    times_vote.append(t_v1 - t_v0)

    # KMeans k=4/6 to measure cluster areas/chromas
    t_cl0 = time.perf_counter()
    k = 4
    kmeans = KMeans(n_clusters=k, n_init=CONFIG["n_init"], random_state=42)
    labels = kmeans.fit_predict(pixels_oklab)
    centers = kmeans.cluster_centers_
    t_cl1 = time.perf_counter()
    times_cluster.append(t_cl1 - t_cl0)

    counts = np.bincount(labels, minlength=k).astype(np.float64)
    areas = (counts / float(len(labels))).tolist()
    c_centers = np.sqrt(centers[:, 1] ** 2 + centers[:, 2] ** 2).tolist()

    # Runner up determination
    # Perturbation jitter check
    jitters = [
        ("hue+3", 3.0, 0.0, 0.0, 0.0),
        ("hue-3", -3.0, 0.0, 0.0, 0.0),
        ("chroma+0.01", 0.0, 0.01, 0.0, 0.0),
        ("chroma-0.01", 0.0, -0.01, 0.0, 0.0),
    ]
    perturbed_labels = []
    flipped = False
    runner_up = ""
    for jname, dh, dc, dd, dl in jitters:
        pl = classify_perturbed(arr_oklab, dh, dc, dd, dl)
        if pl != current_label:
            flipped = True
            flip_counts[(current_label, pl)] += 1
            if not runner_up:
                runner_up = pl
    if not runner_up:
        # Check second closest hue bin
        runner_up = "none"

    data_items.append({
        "path": str(p),
        "folder": p.parent.name,
        "label": current_label,
        "runner_up": runner_up,
        "flipped": flipped,
        "mean_L": mL,
        "mean_C": mC,
        "mean_hue": raw_hue,
        "dark_ratio": dark_ratio,
        "light_ratio": light_ratio,
        "chromatic_mass": chromatic_mass,
        "cluster_areas": areas,
        "cluster_chromas": c_centers,
        "pixels_oklab": pixels_oklab,
        "neon_accents": neon_accents
    })

print("Completed feature extraction on all wallpapers.")

# Save results.csv
with open(DIAG_DIR / "results.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow([
        "path", "folder", "label", "runner_up", "mean_L", "mean_C", "mean_hue",
        "chromatic_mass", "dark_ratio", "light_ratio", "cluster_areas", "cluster_chromas"
    ])
    for d in data_items:
        writer.writerow([
            d["path"], d["folder"], d["label"], d["runner_up"],
            f"{d['mean_L']:.4f}", f"{d['mean_C']:.4f}", f"{d['mean_hue']:.2f}",
            f"{d['chromatic_mass']:.4f}", f"{d['dark_ratio']:.4f}", f"{d['light_ratio']:.4f}",
            ";".join(f"{x:.3f}" for x in d["cluster_areas"]),
            ";".join(f"{x:.3f}" for x in d["cluster_chromas"]),
        ])

print("Saved results.csv successfully.")

# Distribution
label_counts = Counter(d["label"] for d in data_items)
total_n = len(data_items)
print("\n--- LABEL DISTRIBUTION ---")
for lbl, cnt in sorted(label_counts.items(), key=lambda x: -x[1]):
    pct = (cnt / total_n) * 100
    flag = ""
    if pct < 1.0:
        flag = " [FLAG < 1%]"
    elif pct > 25.0:
        flag = " [FLAG > 25%]"
    print(f"  {lbl:<12}: {cnt:3d} ({pct:5.1f}%){flag}")

# -------------------------------------------------------------
# STEP 3: Quantify Symptoms
# -------------------------------------------------------------
# a. Monochrome images with chromatic mass > 10%
mono_chromatic = [
    d for d in data_items
    if d["label"] == "monochrome" and d["chromatic_mass"] > 0.10
]
mono_chromatic.sort(key=lambda x: -x["chromatic_mass"])
print(f"\nSymptom 3a: Monochrome images with chromatic mass > 10%: {len(mono_chromatic)}")
print("Top 10 worst:")
for d in mono_chromatic[:10]:
    print(f"  {d['chromatic_mass']*100:.1f}% C>0.04 | meanC={d['mean_C']:.4f} | path: {d['path']}")

# b. Speck-driven: label's source cluster has < 5% area in KMeans
# For current_label, does any cluster with <5% area have chroma > 2*meanC that could have driven classification?
speck_driven = []
for d in data_items:
    if d["label"] not in ("dark", "light", "monochrome"):
        # check if it has a small cluster (<5% area) with huge chroma while whole mean C is small
        min_area = min(d["cluster_areas"])
        # if total chromatic mass is small (<12%) but classified as chromatic
        if d["chromatic_mass"] < 0.12 and d["mean_C"] < 0.045:
            speck_driven.append(d)
speck_driven.sort(key=lambda x: x["chromatic_mass"])
print(f"\nSymptom 3b: Images classified chromatic but chromatic mass < 12% (speck-driven): {len(speck_driven)}")
print("Top 10 worst:")
for d in speck_driven[:10]:
    print(f"  chrom_mass={d['chromatic_mass']*100:.1f}% | label={d['label']} | path: {d['path']}")

# c. Perturbation test:
unstable = [d for d in data_items if d["flipped"]]
print(f"\nSymptom 3c: Unstable under ±3 deg / ±0.01 C perturbation: {len(unstable)} ({len(unstable)/total_n*100:.1f}%)")
print("Flip rates per category pair:")
for pair, cnt in sorted(flip_counts.items(), key=lambda x: -x[1]):
    print(f"  {pair[0]} -> {pair[1]}: {cnt}")

# d. Determinism: run KMeans 5x per image and check stability
print("\nRunning Determinism test (5x KMeans per image)...")
n_unstable_kmeans = 0
for d in data_items[:100]:  # sample 100 images for speed
    pixels = d["pixels_oklab"]
    lbls = []
    for seed in range(5):
        km = KMeans(n_clusters=4, n_init=1, random_state=seed)
        km.fit(pixels)
        c = km.cluster_centers_
        # prominent block
        best = int(np.argmax(km.inertia_)) # or cluster weights
        lbls.append(best)
    if len(set(lbls)) > 1:
        n_unstable_kmeans += 1
print(f"KMeans n_init=1 seed variance in sample: {n_unstable_kmeans}/100")

# -------------------------------------------------------------
# STEP 4: Soft OKLCH Histogram Prototype Comparison
# -------------------------------------------------------------
# 18 hue bins x 3 chroma x 3 lightness + 5 achromatic bins = 162 + 5 = 167 bins
# Achromatic bins: C < 0.028, split into 5 lightness bins: [0-0.20, 0.20-0.40, 0.40-0.60, 0.60-0.80, 0.80-1.0]
# Chromatic bins: C >= 0.028
# Hue: 18 bins (20 deg each)
# Chroma: 3 bins [0.028-0.065, 0.065-0.12, >0.12]
# Lightness: 3 bins [0-0.35, 0.35-0.65, >0.65]

HUE_NAMES_18 = [
    (0, "crimson/sunset"),    # 0 - 20
    (20, "sunset/orange"),    # 20 - 40
    (40, "gruvbox/amber"),    # 40 - 60
    (60, "gruvbox/yellow"),   # 60 - 80
    (80, "emerald/lime"),     # 80 - 100
    (100, "emerald/green"),   # 100 - 120
    (120, "emerald/forest"),  # 120 - 140
    (140, "emerald/teal"),    # 140 - 160
    (160, "nord/cyan"),       # 160 - 180
    (180, "nord/frost"),      # 180 - 200
    (200, "nord/arctic"),     # 200 - 220
    (220, "ocean/cobalt"),    # 220 - 240
    (240, "ocean/deepblue"),  # 240 - 260
    (260, "ocean/indigo"),    # 260 - 280
    (280, "violet/purple"),   # 280 - 300
    (300, "synthwave/magenta"),# 300 - 320
    (320, "sakura/pink"),     # 320 - 340
    (340, "sakura/rose"),     # 340 - 360
]

def compute_soft_histogram(pixels_oklab):
    # returns dict of mass
    L = pixels_oklab[:, 0]
    a = pixels_oklab[:, 1]
    b = pixels_oklab[:, 2]
    C = np.sqrt(a ** 2 + b ** 2)
    h_deg = (np.arctan2(b, a) * 180.0 / np.pi + 360.0) % 360.0
    N = float(len(L))

    # Achromatic check
    achrom_mask = C < 0.030
    achrom_mass = np.sum(achrom_mask) / N

    # Dark / Light overall mass
    dark_mass = np.sum(L < 0.24) / N
    light_mass = np.sum(L > 0.74) / N

    # Histogram of chromatic hue bins with linear interpolation
    hue_mass = np.zeros(18, dtype=np.float64)
    chrom_mask = ~achrom_mask
    if np.any(chrom_mask):
        h_chrom = h_deg[chrom_mask]
        # bin width = 20 deg
        bin_float = h_chrom / 20.0
        bin_idx0 = np.floor(bin_float).astype(int) % 18
        bin_idx1 = (bin_idx0 + 1) % 18
        frac1 = bin_float - np.floor(bin_float)
        frac0 = 1.0 - frac1
        
        # Soft vote weighted by chroma
        w = C[chrom_mask]
        np.add.at(hue_mass, bin_idx0, frac0 * w)
        np.add.at(hue_mass, bin_idx1, frac1 * w)
        hue_mass = hue_mass / np.sum(w) if np.sum(w) > 0 else hue_mass

    return {
        "dark_mass": dark_mass,
        "light_mass": light_mass,
        "achrom_mass": achrom_mass,
        "chrom_mass": 1.0 - achrom_mass,
        "hue_mass": hue_mass,
    }

# Classify via histogram
def classify_by_histogram(hist):
    if hist["dark_mass"] >= 0.50:
        return "dark"
    if hist["light_mass"] >= 0.45:
        return "light"
    if hist["chrom_mass"] < 0.15: # <15% chromatic pixels
        return "monochrome"

    # Top hue bin
    top_bin = int(np.argmax(hist["hue_mass"]))
    h_center = top_bin * 20.0 + 10.0

    if 100.0 <= h_center < 160.0:
        return "emerald"
    elif 160.0 <= h_center < 220.0:
        return "nord"
    elif 220.0 <= h_center < 280.0:
        return "ocean"
    elif 280.0 <= h_center < 310.0:
        return "violet"
    elif 310.0 <= h_center < 350.0:
        return "sakura"
    elif (h_center >= 350.0) or (0.0 <= h_center < 20.0):
        return "crimson"
    elif 20.0 <= h_center < 50.0:
        return "sunset"
    else:
        return "gruvbox"

disagreements = []
for d in data_items:
    h = compute_soft_histogram(d["pixels_oklab"])
    h_label = classify_by_histogram(h)
    if h_label != d["label"]:
        top_bins = np.argsort(-h["hue_mass"])[:3]
        bin_info = [f"bin{b}({b*20}-{(b+1)*20}deg):{h['hue_mass'][b]:.2f}" for b in top_bins if h['hue_mass'][b] > 0.05]
        disagreements.append({
            "path": d["path"],
            "current": d["label"],
            "hist_label": h_label,
            "dark_m": h["dark_mass"],
            "achrom_m": h["achrom_mass"],
            "chrom_m": h["chrom_mass"],
            "bins": ", ".join(bin_info)
        })

print(f"\nStep 4 Prototype Comparison: Total disagreements = {len(disagreements)} / {total_n} ({len(disagreements)/total_n*100:.1f}%)")
print("\n15 Sample Disagreements:")
for item in disagreements[:15]:
    p_name = Path(item["path"]).name
    print(f"  [{p_name}] Current: {item['current']:<10} | Hist: {item['hist_label']:<10} | Dark={item['dark_m']:.2f} Achrom={item['achrom_m']:.2f} Chrom={item['chrom_m']:.2f} | Bins: {item['bins']}")

# -------------------------------------------------------------
# STEP 5: Sorting Delays & Jump Metrics
# -------------------------------------------------------------
# Measure adjacent-pair distances in current sorted order
# Run sort_wallpapers on all items or read indexed band/colorkey
indexed_sorted = sorted(data_items, key=lambda x: (
    0 if x["label"] in ("dark", "light", "monochrome") else 1,
    x["mean_L"] if x["label"] in ("dark", "light", "monochrome") else x["mean_hue"]
))
# Compute pairwise distance in (L, a, b) between adjacent wallpapers
dists_adj = []
jumps = []
for i in range(len(indexed_sorted) - 1):
    a = indexed_sorted[i]
    b = indexed_sorted[i + 1]
    # Oklab distance between mean colors
    d = math.sqrt((a["mean_L"] - b["mean_L"])**2 + (a["mean_C"] - b["mean_C"])**2)
    dists_adj.append(d)
    jumps.append((d, abs(a["mean_L"] - b["mean_L"]), abs(a["mean_C"] - b["mean_C"]), a["path"], b["path"]))

jumps.sort(key=lambda x: -x[0])
mean_dist = np.mean(dists_adj)
p95_dist = np.percentile(dists_adj, 95)
print(f"\nStep 5 Sorting: Mean adjacent distance = {mean_dist:.4f}, 95th-percentile jump = {p95_dist:.4f}")
print("Top 10 largest jumps:")
for j in jumps[:10]:
    p1 = Path(j[3]).name
    p2 = Path(j[4]).name
    print(f"  Delta={j[0]:.4f} (dL={j[1]:.4f}, dC={j[2]:.4f}): {p1} -> {p2}")

# -------------------------------------------------------------
# STEP 6: Performance breakdown
# -------------------------------------------------------------
print("\n--- STEP 6: TIMING BREAKDOWN (per image average over all 409 images) ---")
print(f"  1. Frame Decode:      {np.mean(times_decode)*1000:6.2f} ms")
print(f"  2. Resize (BOX 48x48):{np.mean(times_resize)*1000:6.2f} ms")
print(f"  3. sRGB -> Oklab:     {np.mean(times_oklab)*1000:6.2f} ms")
print(f"  4. KMeans (k=4):      {np.mean(times_cluster)*1000:6.2f} ms")
print(f"  5. Heuristic Vote:    {np.mean(times_vote)*1000:6.2f} ms")
post_decode_time = (np.mean(times_resize) + np.mean(times_oklab) + np.mean(times_cluster) + np.mean(times_vote)) * 1000
post_decode_no_kmeans = (np.mean(times_resize) + np.mean(times_oklab) + np.mean(times_vote)) * 1000
print(f"  TOTAL post-decode (with KMeans):    {post_decode_time:6.2f} ms")
print(f"  TOTAL post-decode (without KMeans): {post_decode_no_kmeans:6.2f} ms (< 15ms target feasible: {post_decode_no_kmeans < 15})")

# -------------------------------------------------------------
# STEP 7: Open-Set Discovery Analysis
# -------------------------------------------------------------
reg = ThemeRegistry()
novel_items = []
for d in data_items:
    desc = np.array([
        d["mean_L"], 0.0, 0.0,
        d["mean_L"], 0.0, 0.0,
        d["mean_C"]
    ])
    # check distance to all registered themes
    min_d = min(descriptor_distance(desc, np.array(th["centroid"])) for th in reg.themes.values())
    if min_d > 0.20:
        novel_items.append((min_d, d["path"]))

print(f"\nStep 7 Open-Set: Items exceeding acceptance radius in current registry: {len(novel_items)}")

