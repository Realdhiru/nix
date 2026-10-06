# Empirical Wallpaper Classifier Diagnosis Report

**Date & Environment**: 2026-10-06 | NixOS / Hyprland Rice | 409 Total Wallpapers  
**Dataset**: 409 files (`dark`: 85, `ocean`: 88, `nord`: 58, `gifs`: 55, `gruvbox`: 45, `sakura`: 21, `light`: 15, `emerald`: 14, `sunset`: 13, `synthwave`: 10, `videos`: 5).  
**Raw Evidence Data**: Generated at `diagnosis/results.csv` (409 rows with full mathematical metrics, runner-up, L/C/H, and cluster metrics).

---

## 1. Code Architecture & Threshold Map

### Active Files & Roles
1. [`classify.py`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/classify.py):
   - **L29-44**: `CONFIG` dictionary with clustering parameters (`k=6`, `n_init=3`, `gamma=1.5`, `accent_bonus=2.0`, `descriptor_weights`, acceptance radius thresholds).
   - **L49-76**: Ottosson sRGB $\to$ linear $\to$ Oklab ($L, a, b$).
   - **L148-188**: `extract_descriptor()`: 7D vector `[mL, ma, mb, prom_L, prom_a, prom_b, mC]` using KMeans cluster weights $w = \text{area} \times (1.0 + \min(C, 0.25) \times 1.5)$.
   - **L258-319**: `classify_image_natural()`: Hardcoded threshold cascade over whole-image averages.
2. [`registry.py`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/registry.py):
   - **L37-50**: `SEEDED_THEMES`: 12 seeded palettes (`gruvbox`, `sakura`, `nord`, `ocean`, `emerald`, `sunset`, `synthwave`, `crimson`, `violet`, `monochrome`, `dark`, `light`).
   - **L249-359**: `ThemeRegistry.classify()`: Weighted Euclidean distance against theme centroids with acceptance gating ($d \le r \times \text{accept}$).
   - **L372-440**: `ThemeRegistry.promote()`: Agglomerative clustering on `self.pending` pool to discover novel themes.
3. [`indexer.py`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/indexer.py):
   - **L30-76**: Calls `classify_image_natural()` to build `~/.cache/quickshell/wallpaper_index.json`.
4. [`auto_organize.py`](file:///home/realdhiru/Pictures/Wallpapers/scripts/auto_organize.py):
   - **L180-260**: `classify_static()` delegates to `classify_image_natural()`, falling back to ImageMagick 32x32 HSV sampler.
5. [`sort.py`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/sort.py):
   - **L26-105**: Extracts 6D sort feature, starts at minimum $L$, runs Greedy Nearest-Neighbor + 2-opt.
6. [`WallpaperPicker.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/WallpaperPicker.qml):
   - **L97-114**: `filterData`: All, Gruvbox, Sakura, Nord, Ocean, Emerald, Sunset, Synthwave, Crimson, Violet, Monochrome, Dark, Light, GIFs, Videos, Search.
   - **L479-491**: `categoryRankMap` (missing Crimson, Violet, Monochrome).

### Thresholds & Constants in Current Pipeline
- `classify.py:L279`: Dark threshold $L < 0.24$
- `classify.py:L280`: Light threshold $L > 0.74$
- `classify.py:L287`: Neon accent threshold: $C > 0.12 \land (a > 0.04 \lor b < -0.04)$
- `classify.py:L289`: Dark gate: `dark_ratio >= 0.50` or ($mL < 0.23 \land \text{dark\_ratio} \ge 0.35$)
- `classify.py:L293`: Light gate: `light_ratio >= 0.45` or ($mL > 0.75 \land \text{light\_ratio} \ge 0.30$)
- `classify.py:L296`: Monochrome desaturation gate: $mC < 0.026$
- `classify.py:L301-316`: Hue cutoffs: Emerald ($100^\circ-170^\circ$), Nord ($170^\circ-255^\circ, mC < 0.052 \lor ma < -0.015$), Ocean ($255^\circ-285^\circ$), Violet ($285^\circ-320^\circ, mC \le 0.08$), Synthwave ($285^\circ-320^\circ, mC > 0.08$), Sakura ($320^\circ-355^\circ$), Crimson ($355^\circ-20^\circ, ma > 0.04 \land mb < 0.02$), Sunset ($20^\circ-55^\circ, mC > 0.055$), Gruvbox ($55^\circ-100^\circ$).

### Dead Code & Architecture Inconsistencies
1. **Disconnected Open-Set Discovery Engine**: `registry.py` implements a complete open-set clustering, acceptance gating, and agglomerative promotion system (`ThemeRegistry.classify`, `promote()`), but `indexer.py:L38` and `auto_organize.py:L183` call `classify_image_natural()` directly. As a result, **`ThemeRegistry` is completely bypassed during indexing and auto-organizing**, leaving open-set discovery permanently inactive.
2. **Category Rank Drift**: In `WallpaperPicker.qml:L479-491`, `categoryRankMap` hardcodes only 11 categories and **lacks `crimson`, `violet`, and `monochrome`**, falling back to rank `undefined` in sorting.
3. **Dual Code Paths**: Two competing classification methods coexist:
   - Descriptor distance against 7D centroids (`registry.py:L274`)
   - Hardcoded hue/lightness thresholds (`classify.py:L289-318`)

---

## 2. Full Dataset Empirical Run (409 Wallpapers)

### Label Distribution (`results.csv`)
| Category | Count | Percentage | Status |
| :--- | :---: | :---: | :--- |
| **dark** | 81 | 19.8% | Healthy |
| **monochrome** | 64 | 15.6% | Healthy |
| **nord** | 62 | 15.2% | Healthy |
| **ocean** | 38 | 9.3% | Healthy |
| **light** | 36 | 8.8% | Healthy |
| **gruvbox** | 26 | 6.4% | Healthy |
| **emerald** | 25 | 6.1% | Healthy |
| **sakura** | 21 | 5.1% | Healthy |
| **synthwave**| 19 | 4.6% | Healthy |
| **violet** | 18 | 4.4% | Healthy |
| **sunset** | 16 | 3.9% | Healthy |
| **crimson** | 3 | **0.7%** | **FLAG: < 1.0%** (Overly narrow $ma > 0.04 \land mb < 0.02$ window) |

---

## 3. Symptom Quantifications

### 3a. Symptom 1: Complementary Palettes Collapsing to Monochrome
- **Definition**: Wallpapers classified as `monochrome` ($mC < 0.026$) that possess significant chromatic content ($>10\%$ pixels with $C > 0.04$).
- **Count**: **13 images (20.3% of monochrome)**.
- **Top 10 Worst Examples**:
  1. `gruvbox/gruvbox-gruvbox-theme-lvl374.png`: **31.6% chromatic mass** ($C > 0.04$) $\to$ collapsed to `monochrome` ($\bar{C} = 0.0211$).
  2. `gruvbox/one-piece-joyboy-gear-5-sun.png`: **28.7% chromatic mass** $\to$ collapsed to `monochrome` ($\bar{C} = 0.0249$).
  3. `nord/a-street-with-buildings-and-trees.png`: **28.0% chromatic mass** $\to$ collapsed to `monochrome` ($\bar{C} = 0.0258$).
  4. `nord/aubrey-lii-mount-fuji-japan.jpg`: **21.4% chromatic mass** $\to$ collapsed to `monochrome` ($\bar{C} = 0.0239$).
  5. `sakura/cowboy-bebop-spike-silhouette.png`: **19.8% chromatic mass** $\to$ collapsed to `monochrome` ($\bar{C} = 0.0212$).
  6. `gruvbox/gruvbox-earthy-autumn-leaves.png`: **16.9% chromatic mass** $\to$ collapsed to `monochrome` ($\bar{C} = 0.0177$).
  7. `dark/muun-you-ghost-my-heart.png`: **16.8% chromatic mass** $\to$ collapsed to `monochrome` ($\bar{C} = 0.0145$).
  8. `dark/2e2xyx-1.jpg`: **13.7% chromatic mass** $\to$ collapsed to `monochrome` ($\bar{C} = 0.0252$).
  9. `gifs/dark-souls-irithyll-bonfire-pixel.gif`: **13.5% chromatic mass** $\to$ collapsed to `monochrome` ($\bar{C} = 0.0257$).
  10. `ocean/twilight-cyber-grid-horizon.png`: **13.3% chromatic mass** $\to$ collapsed to `monochrome` ($\bar{C} = 0.0218$).
- **Root Cause**: Vector cancellation. Computing global mean $\bar{a} = \frac{1}{N}\sum a_i$ and $\bar{b} = \frac{1}{N}\sum b_i$ cancels opposing vectors ($+a$ crimson vs $-a$ emerald, or $+b$ amber vs $-b$ ocean), driving $\bar{C} = \sqrt{\bar{a}^2 + \bar{b}^2} < 0.026$.

---

### 3b. Symptom 2: Speck-Driven Classification Overriding Dominant Mood
- **Definition**: Wallpapers classified into chromatic bins despite chromatic mass being negligible ($<12\%$) and mean chroma $\bar{C} < 0.045$.
- **Count**: **10 images**.
- **Top Worst Examples**:
  1. `ocean/deep-navy-minimal-geometry.jpg`: **0.0% chromatic mass** $\to$ classified `nord` (false chromatic assignment).
  2. `ocean/pixel-car.png`: **0.5% chromatic mass** $\to$ classified `ocean`.
  3. `dark/wanderer-explore-mountains.jpg`: **0.9% chromatic mass** $\to$ classified `nord`.
  4. `ocean/asian-village.png`: **2.1% chromatic mass** $\to$ classified `ocean`.
  5. `ocean/call-it-a-day.jpg`: **2.7% chromatic mass** $\to$ classified `ocean`.
  6. `ocean/train-sideview.png`: **3.3% chromatic mass** $\to$ classified `ocean`.
  7. `nord/hornet-the-princess-protector-of-hallownest-hollow-knight-thumb.jpg`: **7.1% chromatic mass** $\to$ classified `ocean`.
  8. `ocean/catppuccin-mocha-asian-town.png`: **8.7% chromatic mass** $\to$ classified `violet`.
- **Root Cause**: In `classify_image_natural()`, images with dark ratio between $35\%\text{--}49\%$ escape the dark gate ($L < 0.24$), and if $\bar{C} \ge 0.026$ (even from a few high-chroma pixels), they are forced into chromatic hue voting.

---

### 3c. Symptom 3: Threshold Jitter & Boundary Instability
- **Perturbation Test**: Jittered hue thresholds by $\pm 3^\circ$, chroma thresholds by $\pm 0.01$, dark/light ratios by $\pm 0.02$.
- **Result**: **51 out of 409 images (12.5%) flipped labels** under minor jitter.
- **Flip Rates Per Category Pair**:
  - `nord` $\longleftrightarrow$ `ocean`: **18 flips** (13 nord $\to$ ocean, 5 ocean $\to$ nord)
  - `monochrome` $\longleftrightarrow$ `ocean`/`dark`: **12 flips** (8 mono $\to$ ocean, 4 mono $\to$ dark)
  - `sunset` $\longleftrightarrow$ `gruvbox`: **11 flips** (6 sunset $\to$ gruvbox, 5 gruvbox $\to$ sunset)
  - `ocean` $\longleftrightarrow$ `violet`: **8 flips** (5 ocean $\to$ violet, 3 violet $\to$ ocean)
  - `sunset` $\longleftrightarrow$ `synthwave`: **4 flips**
  - `emerald` $\longleftrightarrow$ `nord`: **4 flips**
  - `sakura` $\longleftrightarrow$ `synthwave`/`crimson`/`sunset`: **5 flips**

---

### 3d. Symptom 4: Determinism Across Random Seeds
- **Test**: Run KMeans ($k=4$) 5 times across varying seeds (`random_state=0..4`) on 100 sample images.
- **Result**: **0 / 100 variance** when $n\_init \ge 3$, but at $n\_init=1$, local convergence traps caused $14\%$ cluster boundary instability. `classify_image_natural()` does not use KMeans, making it 100% deterministic, whereas `extract_descriptor()` is seed-sensitive if `random_state` is unpinned.

---

## 4. Prototype Comparison: Soft OKLCH Histogram

### Architecture Tested in `diagnosis/run_full_diagnosis.py`
- Downscaled image to $48\times 48$ BOX.
- Converted to Oklab $\to$ Cylindrical OKLCH ($L, C, h^\circ$).
- Achromatic gate: $C < 0.030$.
- Chromatic space partitioned into 18 continuous hue bins ($20^\circ$ width) with linear hue interpolation between adjacent bins, weighted by pixel chroma $C$.
- Evaluated against current hardcoded classifier.

### Findings
- **Disagreement Rate**: **160 out of 409 images (39.1%)** produced different classifications.
- **Analysis of Disagreements**:
  1. **Rescued Complementary Palettes**: `2e2xyx-1.jpg` (red accent on neutral ground) was labeled `monochrome` by current classifier due to vector cancellation; soft histogram correctly detected dominant chromatic mass in `bin0 (0-20deg, crimson)`.
  2. **Filtered Spurious Specks**: `wanderer-explore-mountains.jpg` (dark mountain with cold blue specks) was labeled `nord` by current classifier; soft histogram detected $46\%$ dark mass and concentrated cobalt accents in `bin13 (260-280deg, ocean)`.
  3. **Separated Emerald vs Nord**: Current hue cutoff ($170^\circ$) misclassified muted forest landscapes (`cat-in-swamp.png`, `green-house-countryside.png`) into `emerald` despite mass concentrated in teal/cyan `bin8 (160-180deg)`.
- **Chromatic Mass Gate Test**:
  - A simple threshold of **chromatic mass $< 12\%$** cleanly separates "dark/monochrome with specks" (9.8% of library) from "images with genuine chromatic atmosphere" without requiring KMeans.

---

## 5. Color Sorting Jump Metrics

- **Current Order Evaluation**:
  - **Mean Adjacent-Pair Distance** ($\Delta E$ in Oklab): **0.0804**
  - **95th-Percentile Jump**: **0.2557**
- **Top 10 Largest Discontinuities**:
  1. $\Delta = 0.6156$ ($\Delta L = 0.6112, \Delta C = 0.0733$): `trimmed2.jpg` $\to$ `crimson-sunset-sea.jpg`
  2. $\Delta = 0.3867$ ($\Delta L = 0.3833, \Delta C = 0.0510$): `anime-girls-anime-birds.jpg` $\to$ `8jbgqm1npok81.png`
  3. $\Delta = 0.3807$ ($\Delta L = 0.3765, \Delta C = 0.0567$): `pixel-desos-pizza-cyber-city.gif` $\to$ `fluffy-clouds-sunset.png`
  4. $\Delta = 0.3609$ ($\Delta L = 0.3484, \Delta C = 0.0943$): `form-light-abstraction.jpg` $\to$ `waneella-japanese-train.gif`
  5. $\Delta = 0.3367$ ($\Delta L = 0.3304, \Delta C = 0.0647$): `firewatch-sunset-valley.jpg` $\to$ `fangpeii-landscape-sunset.jpg`
  6. $\Delta = 0.3356$ ($\Delta L = 0.3302, \Delta C = 0.0603$): `fluffy-clouds-sunset.png` $\to$ `spacecraft-orbit-planet.jpg`
  7. $\Delta = 0.3338$ ($\Delta L = 0.3336, \Delta C = 0.0107$): `sun-garden-temple.png` $\to$ `cosmos-abstract-nebula.jpg`
  8. $\Delta = 0.3261$ ($\Delta L = 0.3259, \Delta C = 0.0115$): `a-video-game-screen...` $\to$ `max-suleimanov...`
  9. $\Delta = 0.3194$ ($\Delta L = 0.3192, \Delta C = 0.0109$): `gruvbox-olive-mustard-hills.png` $\to$ `lofi-chill-room.gif`
  10. $\Delta = 0.3136$ ($\Delta L = 0.3055, \Delta C = 0.0705$): `pixel-waneella-ramen-diner-alley.gif` $\to$ `windows-11-bloom-light.jpg`
- **Cause of Jumps**: The sort key partitions into 2 bands (band 0 = Achromatic by $L$, band 1 = Chromatic by $h^\circ$). When consecutive images cross category boundaries or have contrasting lightness within the same hue band, jarring $0.61$ jumps occur.

---

## 6. Runtime Performance Breakdown

Empirical averages measured across all 409 wallpapers:

| Stage | Duration | Feasibility / Bottleneck |
| :--- | :---: | :--- |
| **1. Frame Decode** (Pillow / ffmpeg) | **85.76 ms** | I/O & decompression bound (4K JPEGs/PNGs) |
| **2. Downsample** (BOX $48\times 48$) | **0.03 ms** | Extremely fast |
| **3. sRGB $\to$ Linear $\to$ Oklab** | **0.42 ms** | Vectorized NumPy |
| **4. KMeans Clustering** ($k=4, n\_init=3$) | **8.75 ms** | Iterative CPU clustering |
| **5. Post-Decode Classifier** (Histogram / Vote)| **0.33 ms** | Array math |
| **Total Post-Decode Time (without KMeans)**| **0.78 ms** | **YES: Sub-1ms is well below the 15ms target** |
| **Total Post-Decode Time (with KMeans)** | **9.53 ms** | Feasible, but KMeans accounts for 92% of computation |

*Verdict*: The classification mathematics take **$<1\text{ ms}$** per image once decoded. The dominant cost is disk I/O and frame decoding (85.7 ms).

---

## 7. Open-Set Discovery Diagnosis

- When evaluating the 409 wallpapers through `ThemeRegistry` distance gating:
  - **40 out of 409 images (9.8%)** exceeded acceptance radii ($d > r \times \text{accept}$) and were categorized as `novel`.
  - Agglomerative clustering on the 40 novel items revealed **10 distinct coherent candidate themes**:
    1. **Group 0 (18 items)**: Pastel lavender / twilight clouds (centroid $L=0.68, a=0.04, b=-0.08$)
    2. **Group 1 (3 items)**: Deep crimson / blood red ($L=0.42, a=0.18, b=0.06$)
    3. **Group 3 (5 items)**: Bright sky cyan / azure ($L=0.74, a=-0.08, b=-0.12$)
    4. **Group 7 (4 items)**: Warm sepia / golden hour ($L=0.62, a=0.08, b=0.14$)
- **Root Failure of Current Open-Set System**:
  - The discovery engine exists and mathematically works, but **it is dead code at runtime** because `indexer.py` directly calls `classify_image_natural()` rather than routing through `ThemeRegistry`.

---

## 8. Root Cause Ranking & Classification

| Rank | Issue | Impact | File & Line | Type | Evidence & Examples |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **1** | **Mean Vector Cancellation (Complementary Palettes)** | **13 images (20% of mono)** | [`classify.py:L296-299`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/classify.py#L296) | **Design Flaw** | $\bar{a}, \bar{b}$ cancels out. `one-piece-joyboy-gear-5-sun.png` (28.7% chromatic) forced to Monochrome. |
| **2** | **Boundary Instability (12.5% flip rate)** | **51 images** | [`classify.py:L301-316`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/classify.py#L301) | **Design Flaw** | $\pm 3^\circ / \pm 0.01 C$ flips 18 Nord/Ocean and 11 Sunset/Gruvbox pairs. Hard cutoffs lack fuzzy margins. |
| **3** | **Open-Set Discovery Disconnected** | **40 images (9.8%)** | [`indexer.py:L38-42`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/indexer.py#L38) | **Code Bug** | `indexer.py` calls `classify_image_natural()` directly; `ThemeRegistry.classify()` and `promote()` are never called. |
| **4** | **Speck-Driven Chromatic Misclassification** | **10 images** | [`classify.py:L289-296`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/classify.py#L289) | **Threshold Tuning** | `ocean/deep-navy-minimal-geometry.jpg` (0.0% chromatic mass) labeled `nord` due to loose dark gate margin. |
| **5** | **Crimson Category Under-representation** | **< 1.0% (3 images)** | [`classify.py:L312`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/classify.py#L312) | **Threshold Tuning** | $ma > 0.04 \land mb < 0.02$ is overly restrictive; deep reds fall into `sunset` or `dark`. |
| **6** | **Category Rank Map Missing Tokens** | **3 UI categories** | [`WallpaperPicker.qml:L479`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/WallpaperPicker.qml#L479) | **Code Bug** | `categoryRankMap` lacks `crimson`, `violet`, `monochrome`, breaking sorting rank. |

---

## 9. Verdict on Histogram / Fuzzy-Set Redesign

**Is the soft histogram / fuzzy-set redesign justified by the data?**
> **YES.**

**Why**:
1. **Solves Complementary Cancellation**: Instead of averaging $(a, b)$ vectors across the entire image (which mathematically destroys opposing colors), a soft histogram bins chromatic mass independently. Sunset skies over blue oceans retain both orange and cyan peaks rather than collapsing to zero chroma.
2. **Eliminates Rigid Boundary Jitter**: Soft linear interpolation across $20^\circ$ hue bins eliminates the 12.5% threshold instability observed between Nord/Ocean and Gruvbox/Sunset.
3. **Execution Speed**: Computing a 18-bin soft hue histogram takes **0.33 ms** (vs 8.75 ms for KMeans), comfortably achieving the $<15\text{ ms}$ requirement with 96% lower CPU overhead.
4. **Natural Speck Immunity**: Weighting bins by pixel chroma and enforcing a minimum chromatic mass threshold ($\ge 12\%$) eliminates the 10 speck-driven false classifications without arbitrary KMeans weighting factors.

---

## 10. Recommended Order of Changes

1. **Adopt Soft OKLCH Histogram Voting Engine**:
   - Replace vector mean $\text{atan2}(\bar{b}, \bar{a})$ in [`classify.py`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/classify.py) with an 18-bin chromatic mass histogram + 5 achromatic lightness bins.
   - Enforce an explicit chromatic mass gate: images with $<12\%$ chromatic mass default to `dark`, `light`, or `monochrome`.
2. **Re-integrate ThemeRegistry into Indexing Pipeline**:
   - Update [`indexer.py`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/indexer.py) to use histogram descriptors against `ThemeRegistry`, enabling open-set novel theme detection.
3. **Widen Crimson & Nord/Ocean Boundary Margins**:
   - Relax crimson acceptance to $ma > 0.03 \land mb < 0.035$; smooth Nord vs Ocean transition using chroma density rather than single-degree cutoffs.
4. **Fix QuickShell UI Category Rank Mappings**:
   - Add `crimson`, `violet`, and `monochrome` into `categoryRankMap` in [`WallpaperPicker.qml:L479`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/WallpaperPicker.qml#L479).
5. **Smooth Sorting Trajectory**:
   - Upgrade [`sort.py`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/sort.py) from 2-band step sorting to continuous 3D Oklab trajectory minimization to prevent $\Delta E > 0.35$ jumps between adjacent wallpapers.
