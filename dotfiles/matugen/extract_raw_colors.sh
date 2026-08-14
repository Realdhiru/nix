#!/usr/bin/env bash
# Extract a raw, strictly wallpaper-derived palette into qs_colors.json
# (Quickshell + lockscreen). No hardcoded colors: every hex originates from
# the input image, or — when the image has no color variety — from a neutral
# ramp derived from the image's dominant tone. On any failure the matugen
# template output is left untouched as the fallback palette.

set -euo pipefail

WALL="${1:-}"
CACHE_FILE="$HOME/.cache/matugen/qs_colors.json"

# Allow ImageMagick frame syntax ("file.gif[0]") while still checking the
# underlying file exists.
WALL_BASE="${WALL%%\[*}"
if [[ -z "$WALL" ]] || [[ ! -f "$WALL_BASE" ]]; then
    echo "extract_raw_colors: no valid image given, keeping fallback palette" >&2
    exit 0
fi

if ! command -v magick >/dev/null 2>&1; then
    echo "extract_raw_colors: magick unavailable, keeping fallback palette" >&2
    exit 0
fi

HIST_FILE="$(mktemp)"
if ! magick "$WALL" -resize '160x160!' -colors 8 -depth 8 -format %c histogram:info:- > "$HIST_FILE" 2>/dev/null; then
    rm -f "$HIST_FILE"
    exit 0
fi

if ! python3 - <<'PY' "$HIST_FILE" > "${CACHE_FILE}.tmp" 2>/dev/null
# argv[1]: magick histogram lines "  count: (r%,g%,b%) #HEX srgb(...)"
# stdout: the 22-key qs_colors.json
import sys, colorsys, json

ACCENT_SLOTS = ["blue", "sapphire", "mauve", "green", "peach",
                "pink", "teal", "yellow", "red", "maroon"]

def parse():
    rows = []
    with open(sys.argv[1]) as fh:
        for line in fh:
            line = line.strip()
            if not line or "#" not in line:
                continue
            try:
                count = int(line.split(":")[0].strip())
                hexv = line.split("#")[1].split()[0][:6].lower()
                if len(hexv) == 6:
                    rows.append((count, hexv))
            except Exception:
                continue
    return rows

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

def hsv(h):
    return colorsys.rgb_to_hsv(*rgb(h))

def lum(h):
    r, g, b = rgb(h)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def darken(h, pct):
    f = 1 - pct / 100
    return "%02x%02x%02x" % tuple(round(c * f * 255) for c in rgb(h))

def mix(a, b, t):
    return "%02x%02x%02x" % tuple(round((x * (1 - t) + y * t) * 255)
                                  for x, y in zip(rgb(a), rgb(b)))

rows = parse()
if not rows:
    sys.exit(1)
rows.sort(key=lambda p: -p[0])

kept = []
for _count, h in rows:
    hh, _s, _v = hsv(h)
    hlum = lum(h)
    ok = True
    for kh in kept:
        khh, _ks, _kv = hsv(kh)
        dh = abs(hh - khh)
        dh = min(dh, 1 - dh)
        if dh < 12 / 360 and abs(hlum - lum(kh)) < 0.25:
            ok = False
            break
    if ok:
        kept.append(h)
    if len(kept) >= 6:
        break

def rel_lum(h):
    def lin(c):
        return c / 12.92 if c <= 0.0392822 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = rgb(h)
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)

def contrast(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

def set_luminance(h, target):
    # Binary search HSL lightness, preserving hue and saturation exactly.
    hh, ll, ss = colorsys.rgb_to_hls(*rgb(h))
    lo_L, hi_L = 0.0, 1.0
    for _ in range(10):
        mid = (lo_L + hi_L) / 2
        cr, cg, cb = colorsys.hls_to_rgb(hh, mid, ss)
        probe = "%02x%02x%02x" % (round(cr * 255), round(cg * 255), round(cb * 255))
        if rel_lum(probe) < target:
            lo_L = mid
        else:
            hi_L = mid
    cr, cg, cb = colorsys.hls_to_rgb(hh, (lo_L + hi_L) / 2, ss)
    return "%02x%02x%02x" % (round(cr * 255), round(cg * 255), round(cb * 255))

MIN_SEP = 2.0   # minimum contrast (WCAG formula) between UI base and wallpaper
MIN_LUM, MAX_LUM = 0.045, 0.92

top3 = rows[:3]
mean_sat = sum(hsv(h)[1] for _c, h in top3) / len(top3)
dominant = rows[0][1]

varied = len(kept) >= 2 and mean_sat >= 0.05

if varied:
    base = min(kept, key=lum)
    accents = kept
else:
    base = dominant
    accents = [darken(base, 10), darken(base, 20), darken(base, 30),
               darken(base, 40), darken(base, 50), darken(base, 60)]

# Adaptive UI-surface separation: keep the wallpaper's hue, but guarantee the
# panel is visibly distinct from the wallpaper tone behind it.
wall_bg = dominant
if contrast(wall_bg, base) < MIN_SEP:
    lw = rel_lum(wall_bg)
    if lw < 0.5:
        target = MIN_SEP * (lw + 0.05) - 0.05
    else:
        target = (lw + 0.05) / MIN_SEP - 0.05
    target = min(max(target, MIN_LUM), MAX_LUM)
    base = set_luminance(base, target)

text = "ffffff" if contrast("ffffff", base) >= 4.5 else "000000"

palette = {
    "base": base,
    "mantle": darken(base, 6),
    "crust": darken(base, 10),
    "text": text,
    "subtext0": mix(text, base, 0.30),
    "subtext1": mix(text, base, 0.15),
    "surface0": darken(base, 8),
    "surface1": darken(base, 16),
    "surface2": darken(base, 24),
    "overlay0": mix(text, base, 0.30),
    "overlay1": mix(text, base, 0.40),
    "overlay2": mix(text, base, 0.50),
}

for i, slot in enumerate(ACCENT_SLOTS):
    palette[slot] = accents[i % len(accents)]

sys.stdout.write(json.dumps({k: "#" + v for k, v in palette.items()}))
PY
then
    echo "extract_raw_colors: palette generation failed, keeping fallback palette" >&2
    rm -f "${CACHE_FILE}.tmp"
    exit 0
fi

if ! python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if set(d) >= set("base mantle crust text subtext0 subtext1 surface0 surface1 surface2 overlay0 overlay1 overlay2 blue sapphire peach green red mauve pink yellow maroon teal".split()) else 1)' "${CACHE_FILE}.tmp"; then
    echo "extract_raw_colors: generated palette invalid, keeping fallback palette" >&2
    rm -f "${CACHE_FILE}.tmp"
    exit 0
fi

mv -f "${CACHE_FILE}.tmp" "$CACHE_FILE"
rm -f "$HIST_FILE"
