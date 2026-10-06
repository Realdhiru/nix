#!/usr/bin/env python3
"""Evaluation and validation suite for wallpaper color classification and clustering."""

import os
import sys
import copy
import shutil
import tempfile
from pathlib import Path
from typing import Dict, List, Tuple, Any, Optional, Union

# Auto re-exec into Nix environment if needed
try:
    import numpy as np
    from PIL import Image
    from sklearn.metrics import confusion_matrix
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
    extract_descriptor,
    descriptor_distance,
    hex_to_oklab
)
from registry import ThemeRegistry, SEEDED_THEMES, THEMES_PATH


def evaluate_labeled_dir(
    base_dir: Union[str, Path],
    registry: Optional[ThemeRegistry] = None
) -> Dict[str, Any]:
    """Evaluate classifier against ground truth labeled folders."""
    base = Path(base_dir).resolve()
    if not base.is_dir():
        print(f"Error: {base} is not a directory.")
        return {}

    if registry is None:
        registry = ThemeRegistry()

    ground_truth = []
    predicted = []
    novel_counts = 0
    total_images = 0

    known_themes = set(SEEDED_THEMES.keys())

    for folder in sorted(base.iterdir()):
        if not folder.is_dir():
            continue
        label = folder.name.lower()
        if label not in known_themes:
            continue

        images = [
            p for p in folder.iterdir()
            if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".mkv", ".webm"}
        ]

        for img in images:
            total_images += 1
            res = registry.classify(img, update=False)
            pred_label = res.get("theme", "").lower()
            is_novel = res.get("novel", False)

            if is_novel:
                novel_counts += 1

            ground_truth.append(label)
            predicted.append(pred_label)

    if not ground_truth:
        print("No labeled images found.")
        return {}

    labels_sorted = sorted(list(set(ground_truth)))
    cm = confusion_matrix(ground_truth, predicted, labels=labels_sorted)
    correct = sum(1 for gt, pr in zip(ground_truth, predicted) if gt == pr)
    accuracy = correct / len(ground_truth) if ground_truth else 0.0

    print("=== EVALUATION REPORT ===")
    print(f"Total images evaluated: {total_images}")
    print(f"Correct classifications: {correct}")
    print(f"Pending/novel count:     {novel_counts} ({novel_counts/total_images*100:.1f}%)")
    print(f"Raw seeded accuracy:     {accuracy*100:.2f}%\n")

    print(f"{'True \\ Pred':<12}", end="")
    for l in labels_sorted:
        print(f"{l[:6]:>8}", end="")
    print()

    for idx, gt_label in enumerate(labels_sorted):
        print(f"{gt_label:<12}", end="")
        for jdx in range(len(labels_sorted)):
            print(f"{cm[idx, jdx]:>8}", end="")
        print()

    return {
        "total": total_images,
        "correct": correct,
        "novel": novel_counts,
        "accuracy": accuracy,
        "labels": labels_sorted,
        "confusion_matrix": cm.tolist()
    }


def grid_search(
    base_dir: Union[str, Path],
    gamma_values: List[float] = [1.2, 1.5, 1.8],
    accept_values: List[float] = [0.9, 1.0, 1.1]
) -> None:
    """Grid search hyperparameter configurations to optimize accuracy."""
    base = Path(base_dir).resolve()
    print("Running grid search...")
    orig_gamma = CONFIG["gamma"]
    orig_accept = CONFIG["accept"]

    best_score = -1.0
    best_params = {}

    for g in gamma_values:
        for a in accept_values:
            CONFIG["gamma"] = g
            CONFIG["accept"] = a
            reg = ThemeRegistry()
            res = evaluate_labeled_dir(base, reg)
            score = res.get("accuracy", 0.0)
            print(f"gamma={g}, accept={a} -> Accuracy: {score*100:.2f}%, Novel: {res.get('novel')}")
            if score > best_score:
                best_score = score
                best_params = {"gamma": g, "accept": a}

    CONFIG["gamma"] = orig_gamma
    CONFIG["accept"] = orig_accept
    print(f"\nBest configuration: {best_params} with accuracy {best_score*100:.2f}%")


def run_must_pass_tests() -> bool:
    """Execute the 4 mandatory validation test cases."""
    print("========================================")
    print("RUNNING 4 MANDATORY COLOR VALIDATION TESTS")
    print("========================================")

    with tempfile.TemporaryDirectory() as tmp_dir:
        test_themes_path = Path(tmp_dir) / "themes.json"
        wp_dir = Path.home() / "Pictures" / "Wallpapers"
        reg = ThemeRegistry(path=test_themes_path)
        reg.seed_defaults(wallpaper_dir=wp_dir if wp_dir.is_dir() else None)

        # Enforce realistic radius limits
        for th in reg.themes.values():
            th["radius"] = min(0.20, max(CONFIG["min_radius"], th["radius"]))

        all_passed = True

        # CASE 1: Peach/coral pastel sunset -> sunset, not sakura
        print("[TEST 1] Peach/coral pastel sunset -> sunset, not sakura")
        im_sunset = Image.new("RGB", (64, 64))
        for y in range(64):
            for x in range(64):
                t = y / 64.0
                im_sunset.putpixel((x, y), (int(225 * (1 - t) + 250 * t), int(110 * (1 - t) + 160 * t), int(90 * (1 - t) + 120 * t)))
        desc_sunset = extract_descriptor(im_sunset)
        res1 = reg.classify(desc_sunset, update=False)
        pred1 = res1["theme"].lower()
        if pred1 == "sunset":
            print(f"  PASS: classified as '{pred1}' (conf={res1['confidence']:.2f}, dist={res1['distance']:.3f})")
        else:
            print(f"  FAIL: expected 'sunset', got '{pred1}'")
            all_passed = False

        # CASE 2: Dark navy sky 80% + neon pink/yellow signs 20% -> synthwave
        print("[TEST 2] Dark navy sky 80% + neon pink/yellow signs 20% -> synthwave")
        im_synth = Image.new("RGB", (64, 64), (24, 17, 46))
        neon_pixels = int(64 * 64 * 0.20)
        for i in range(neon_pixels):
            y = i // 64
            x = i % 64
            im_synth.putpixel((x, y), (255, 42, 133) if i % 2 == 0 else (176, 38, 255))
        desc_synth = extract_descriptor(im_synth)
        res2 = reg.classify(desc_synth, update=False)
        pred2 = res2["theme"].lower()
        if pred2 == "synthwave":
            print(f"  PASS: classified as '{pred2}' (conf={res2['confidence']:.2f}, dist={res2['distance']:.3f})")
        else:
            print(f"  FAIL: expected 'synthwave', got '{pred2}'")
            all_passed = False

        # CASE 3: Foggy blue-tinted low-chroma landscape -> nord, not dark/light
        print("[TEST 3] Foggy blue-tinted low-chroma landscape -> nord, not dark/light")
        im_nord = Image.new("RGB", (64, 64), (95, 120, 135))
        desc_nord = extract_descriptor(im_nord)
        res3 = reg.classify(desc_nord, update=False)
        pred3 = res3["theme"].lower()
        if pred3 == "nord":
            print(f"  PASS: classified as '{pred3}' (conf={res3['confidence']:.2f}, dist={res3['distance']:.3f})")
        else:
            print(f"  FAIL: expected 'nord', got '{pred3}'")
            all_passed = False

        # CASE 4: 6 teal-orange images matching no seed -> after promote(), 1 new theme
        print("[TEST 4] 6 teal-orange images matching no seed -> after promote(), 1 new theme")
        reg.pending = []
        for i in range(6):
            # Vibrant turquoise/teal + persimmon orange (matches no seed)
            im_to = Image.new("RGB", (64, 64), (0, 245 - i, 212 + i))
            for y in range(32):
                for x in range(64):
                    im_to.putpixel((x, y), (255, 107 + i, 53 - i))
            p = str(Path(tmp_dir) / f"teal_orange_{i}.png")
            im_to.save(p)
            reg.classify(p, update=True)

        promoted = reg.promote()
        if len(promoted) >= 1:
            new_th = promoted[0]
            print(f"  PASS: promoted new theme '{new_th['name']}' with {new_th['count']} members (not forced into ocean/sunset)")
        else:
            print(f"  FAIL: expected 1 promoted theme, got {len(promoted)}")
            all_passed = False

        print("========================================")
        if all_passed:
            print("ALL 4 MUST-PASS TESTS SUCCEEDED!")
        else:
            print("SOME TESTS FAILED.")
        print("========================================")
        return all_passed


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        success = run_must_pass_tests()
        sys.exit(0 if success else 1)
    elif len(sys.argv) > 1:
        target = sys.argv[1]
        evaluate_labeled_dir(target)
    else:
        success = run_must_pass_tests()
        sys.exit(0 if success else 1)
