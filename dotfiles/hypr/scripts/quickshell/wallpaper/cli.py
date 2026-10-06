#!/usr/bin/env python3
"""Unified CLI for wallpaper color classification, sorting, and theme registry operations."""

import os
import sys
import argparse
from pathlib import Path
from typing import List

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

from registry import ThemeRegistry
from sort import sort_wallpapers, get_theme_display_order
from eval import evaluate_labeled_dir, run_must_pass_tests


def cmd_classify(args: argparse.Namespace, reg: ThemeRegistry) -> None:
    """Classify a single image or directory of wallpapers."""
    target = Path(args.target).resolve()
    if not target.exists():
        print(f"Error: path '{target}' does not exist.")
        sys.exit(1)

    if target.is_file():
        res = reg.classify(target, update=not args.dry_run)
        print(f"File:       {target.name}")
        print(f"Status:     {res.get('status')} (Novel: {res.get('novel')})")
        print(f"Theme:      {res.get('theme')} (ID: {res.get('theme_id')})")
        print(f"Confidence: {res.get('confidence', 0.0):.3f}")
        print(f"Distance:   {res.get('distance', 0.0):.4f}")
        print("Top 3 Candidates:")
        for cand in res.get("top3", []):
            print(f"  - {cand['theme']:<12} conf: {cand['confidence']:.3f} (dist: {cand['distance']:.4f})")
    elif target.is_dir():
        img_exts = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".mkv", ".webm"}
        files = [p for p in target.iterdir() if p.is_file() and p.suffix.lower() in img_exts]
        print(f"Classifying {len(files)} files in '{target.name}'...")
        assigned_counts = {}
        novel_count = 0
        for f in files:
            res = reg.classify(f, update=not args.dry_run)
            if res.get("novel"):
                novel_count += 1
            th = res.get("theme", "unknown")
            assigned_counts[th] = assigned_counts.get(th, 0) + 1

        print("\nClassification Summary:")
        for th, cnt in sorted(assigned_counts.items(), key=lambda x: -x[1]):
            print(f"  {th:<14}: {cnt} items")
        print(f"  Novel/Pending : {novel_count} items")


def cmd_promote(args: argparse.Namespace, reg: ThemeRegistry) -> None:
    """Promote qualifying pending clusters into new themes."""
    promoted = reg.promote()
    if not promoted:
        print(f"No clusters met promotion criteria ({len(reg.pending)} items currently pending).")
    else:
        print(f"Promoted {len(promoted)} new theme(s):")
        for th in promoted:
            print(f"  - {th['name']} (ID: {th['id']}, Members: {th['count']}, Radius: {th['radius']:.3f})")


def cmd_merge(args: argparse.Namespace, reg: ThemeRegistry) -> None:
    """Merge themes with centroid distances closer than merge_dist."""
    merged = reg.merge()
    if not merged:
        print("No themes close enough to merge.")
    else:
        print(f"Merged {len(merged)} theme pair(s):")
        for win, lose in merged:
            print(f"  - Kept '{win}', merged '{lose}'")


def cmd_themes(args: argparse.Namespace, reg: ThemeRegistry) -> None:
    """List all themes, their counts, radii, and pending status."""
    order = get_theme_display_order(reg)
    print(f"{'Name':<16} {'ID':<18} {'Count':<8} {'Seeded':<8} {'Radius':<8}")
    print("-" * 62)
    for t in order:
        th = reg.themes[t["id"]]
        print(f"{th['name']:<16} {th['id']:<18} {th.get('count', 0):<8} {'Yes' if th.get('seeded') else 'No':<8} {th.get('radius', 0.0):<8.3f}")
    print(f"\nPending Pool: {len(reg.pending)} wallpapers awaiting promotion.")


def cmd_rename(args: argparse.Namespace, reg: ThemeRegistry) -> None:
    """Rename a theme."""
    success = reg.rename_theme(args.identifier, args.new_name)
    if success:
        print(f"Successfully renamed theme '{args.identifier}' to '{args.new_name}'.")
    else:
        print(f"Error: Theme '{args.identifier}' not found.")
        sys.exit(1)


def cmd_sort(args: argparse.Namespace) -> None:
    """Sort images in directory along shortest color path."""
    target = Path(args.directory).resolve()
    if not target.is_dir():
        print(f"Error: '{target}' is not a directory.")
        sys.exit(1)

    img_exts = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".mkv", ".webm"}
    files = [p for p in target.iterdir() if p.is_file() and p.suffix.lower() in img_exts]
    sorted_files = sort_wallpapers(files)
    print(f"Sorted {len(sorted_files)} wallpapers along open Oklab path (darkest first):")
    for idx, f in enumerate(sorted_files[:args.limit]):
        print(f"  {idx+1:>3}. {Path(f).name}")
    if len(sorted_files) > args.limit:
        print(f"  ... and {len(sorted_files) - args.limit} more.")


def cmd_eval(args: argparse.Namespace, reg: ThemeRegistry) -> None:
    """Run evaluation or unit tests."""
    if args.labeled_dir == "test":
        success = run_must_pass_tests()
        sys.exit(0 if success else 1)
    else:
        evaluate_labeled_dir(args.labeled_dir, reg)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Wallpaper Color Classifier & Sorter CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # classify
    p_classify = subparsers.add_parser("classify", help="Classify an image or directory")
    p_classify.add_argument("target", help="File path or directory path")
    p_classify.add_argument("--dry-run", action="store_true", help="Do not mutate registry centroids")

    # promote
    subparsers.add_parser("promote", help="Promote qualifying pending clusters into themes")

    # merge
    subparsers.add_parser("merge", help="Merge adjacent themes")

    # themes
    subparsers.add_parser("themes", help="List registered themes and pending count")

    # rename
    p_rename = subparsers.add_parser("rename", help="Rename a theme")
    p_rename.add_argument("identifier", help="Theme ID or current name")
    p_rename.add_argument("new_name", help="New theme name")

    # sort
    p_sort = subparsers.add_parser("sort", help="Sort wallpapers along shortest color path")
    p_sort.add_argument("directory", help="Directory containing wallpapers")
    p_sort.add_argument("--limit", type=int, default=20, help="Number of files to display")

    # eval
    p_eval = subparsers.add_parser("eval", help="Evaluate against labeled directory or run tests")
    p_eval.add_argument("labeled_dir", help="Path to labeled directory, or 'test'")

    args = parser.parse_args()
    reg = ThemeRegistry()

    if args.command == "classify":
        cmd_classify(args, reg)
    elif args.command == "promote":
        cmd_promote(args, reg)
    elif args.command == "merge":
        cmd_merge(args, reg)
    elif args.command == "themes":
        cmd_themes(args, reg)
    elif args.command == "rename":
        cmd_rename(args, reg)
    elif args.command == "sort":
        cmd_sort(args)
    elif args.command == "eval":
        cmd_eval(args, reg)


if __name__ == "__main__":
    main()
