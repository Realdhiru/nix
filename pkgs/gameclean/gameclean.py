#!/usr/bin/env python3
"""
gameclean - find and delete wine/lutris/proton game leftover files.

Usage:
  gameclean          # preview what would be deleted (default, safe)
  gameclean -y       # actually delete
  gameclean -y -q    # delete, minimal output

What it scans:
  1. Orphan wine prefixes in ~/Games/prefixes (referenced by no installed game)
  2. Wine prefixes whose game files are gone (broken exe path in lutris .yml)
  3. Huge Temp + shadercache dirs inside the shared umu/proton prefix
  4. Game caches in ~/.cache (lutris, winetricks, umu, dxvk, rpcs3, winelib...)
  5. Orphan entries in ~/.local/share/lutris/games/*.yml pointing to deleted paths
  6. Stray wine prefixes anywhere under ~/Games (junk created by experiments)
"""
import os, sys, glob, shutil, subprocess, re

HOME = os.path.expanduser("~")
GAMES = os.path.join(HOME, "Games")
PREFIXES = os.path.join(GAMES, "prefixes")
LUTRIS_GAMES = os.path.join(HOME, ".local/share/lutris/games")
UMU_PREFIX = os.path.join(GAMES, "umu/umu-default")
CACHE = os.path.join(HOME, ".cache")

APPLY = "-y" in sys.argv
QUIET = "-q" in sys.argv

CACHE_DIRS = [
    "lutris", "winetricks", "umu", "rpcs3", "dxvk", "dxvk-cache",
    "vkd3d", "winelib", "gamescope", "wine", "steam",
]

def size(p):
    if os.path.isfile(p):
        return os.path.getsize(p)
    total = 0
    for root, _, files in os.walk(p):
        for f in files:
            try:
                total += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
    return total

def human(n):
    for u in ("", "K", "M", "G"):
        if n < 1024: return f"{n:.0f}{u}" if n > 99 or u == "" else f"~{n:.0f}{u}"
        n /= 1024
    return f"{n/1024:.1f}G"

def ymls():
    return sorted(glob.glob(os.path.join(LUTRIS_GAMES, "*.yml")))

def load_yml(p):
    """minimal parser: extract exe/main_file/game_dir/prefix values."""
    for enc in ("utf-16", "utf-8"):
        try:
            t = open(p, encoding=enc).read()
            break
        except Exception:
            t = None
    if t is None:
        return None
    vals = {}
    for m in re.finditer(r'^[ \t]*(\w[A-Za-z_]*):[ \t]*([^\n#]+)$', t, re.M):
        k, v = m.group(1), m.group(2).strip()
        if k in ("exe", "main_file", "game_dir", "prefix"):
            vals.setdefault(k, v.replace("\\ ", " "))
    if vals:
        return {"game": vals}
    return None

def game_prefix_and_root(y):
    """returns (prefix_path, game_root_dir) or None"""
    if not isinstance(y, dict): return None
    g = y.get("game", {}) or {}
    root = None
    for key in ("exe", "main_file", "game_dir"):
        v = g.get(key)
        if isinstance(v, str) and v:
            root = os.path.dirname(v); break
    prefix = g.get("prefix") or (y.get("system", {}) or {}).get("prefix")
    return prefix, root

orphans = []          # list of (path, reason)

# 1+2+5: check lutris entries for broken installs
referenced_prefixes = set()
referenced_roots = set()
for p in ymls():
    y = load_yml(p)
    info = game_prefix_and_root(y)
    if not info:
        continue
    prefix, root = info
    if prefix and os.path.isdir(prefix):
        referenced_prefixes.add(os.path.realpath(prefix))
    if root and os.path.isdir(root):
        referenced_roots.add(os.path.realpath(root))
    else:
        orphans.append((p, "lutris entry points to deleted game files"))

# any prefixes left over that no lutris entry references
if os.path.isdir(PREFIXES):
    for e in os.listdir(PREFIXES):
        p = os.path.join(PREFIXES, e)
        if os.path.realpath(p) not in referenced_prefixes and os.path.isdir(p):
            orphans.append((p, "orphan wine prefix (no game references it)"))

# any prefix dirs created in product folders anywhere under ~/Games
for p in glob.glob(os.path.join(GAMES, "*", "drive_c")):
    base = os.path.dirname(p)
    if base != UMU_PREFIX:
        orphans.append((base, "stray wine prefix inside game folder"))

# 3: umu/proton prefix temp + shadercache junk (keep the prefix alive for FL studio etc.)
if os.path.isdir(UMU_PREFIX):
    junk_names = ("Temp", "shadercache", "temp", "WineShaders", "Shaders")
    for name in junk_names:
        p = os.path.join(UMU_PREFIX, "drive_c/users/steamuser/AppData/Local", name)
        if os.path.isdir(p):
            # only flag if it's big; Temp contains files used *while running*
            orphans.append((p, "wine temp/shadercache inside umu prefix"))
    for extra in (os.path.join(UMU_PREFIX, "shadercache"), os.path.join(UMU_PREFIX, "CaseShaderCache")):
        if os.path.isdir(extra):
            orphans.append((extra, "proton shadercache"))

# 4: game caches
for name in CACHE_DIRS:
    p = os.path.join(CACHE, name)
    if os.path.isdir(p):
        orphans.append((p, "game-related cache"))

total = sum(size(p) for p, _ in orphans)

if QUIET:
    print(f"{human(total)}") if APPLY else None
else:
    print(f"gameclean — total to delete: {human(total)}\n")
    for p, reason in orphans:
        print(f"  {human(size(p))}  {reason}\n        {p}")
    print()
    if not orphans:
        print("Nothing to clean.")

if APPLY and orphans:
    for p, _ in orphans:
        try:
            if os.path.isdir(p):
                shutil.rmtree(p)
            elif os.path.exists(p):
                os.remove(p)
        except Exception as e:
            print(f"failed: {p}: {e}", file=sys.stderr)
    print(f"Deleted. Freed {human(total)}.")
elif not APPLY:
    print("(preview only — run:  gameclean -y   to actually delete)")
