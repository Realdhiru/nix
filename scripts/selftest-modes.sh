#!/usr/bin/env bash
# scripts/selftest-modes.sh
# Comprehensive Mode State Machine Self-Test Suite
# Exhaustively verifies all 10 pairs and all 10 triples across:
# wallpaper-kill, gaming, power-saver, coffee, dnd
# For each pair/triple, verifies both reverse and forward off-order return to baseline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE_CTL="$ROOT_DIR/dotfiles/hypr/scripts/mode_ctl.sh"
DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
MODES_JSON="$DESKTOP_STATE_DIR/modes/modes.json"
ALACRITTY_CONF="$HOME/.cache/theme/alacritty-colors.toml"
PACE="${PACE:-0.15}"

echo "=== Mode State Machine Matrix Self-Test Suite ==="

# Reset modes to clean baseline first
for m in "wallpaper-kill" "gaming" "power-saver" "coffee" "dnd"; do
    bash "$MODE_CTL" set "$m" false >/dev/null 2>&1 || true
done
sleep 0.5

# 1. Snapshot baseline
echo "[1] Snapshotting baseline compositor and mode state..."
SNAPSHOT_BLUR=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | jq -r '.bool // true')
SNAPSHOT_SHADOW=$(hyprctl getoption decoration:shadow:enabled -j 2>/dev/null | jq -r '.bool // true')
SNAPSHOT_ANIM=$(hyprctl getoption animations:enabled -j 2>/dev/null | jq -r '.bool // true')
SNAPSHOT_DIRECT=$(hyprctl getoption render:direct_scanout -j 2>/dev/null | jq -r '.int // 0')
SNAPSHOT_TEAR=$(hyprctl getoption general:allow_tearing -j 2>/dev/null | jq -r '.bool // false')
SNAPSHOT_OPACITY=$(grep -E '^opacity =' "$ALACRITTY_CONF" 2>/dev/null | tr -d ' ' || echo "opacity=0.30")

echo "  Baseline: blur=$SNAPSHOT_BLUR, shadow=$SNAPSHOT_SHADOW, anim=$SNAPSHOT_ANIM, direct_scanout=$SNAPSHOT_DIRECT, tearing=$SNAPSHOT_TEAR, $SNAPSHOT_OPACITY"

assert_baseline() {
    local context="$1"
    local cur_blur cur_shadow cur_anim cur_direct cur_tear cur_opacity
    cur_blur=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | jq -r '.bool // true')
    cur_shadow=$(hyprctl getoption decoration:shadow:enabled -j 2>/dev/null | jq -r '.bool // true')
    cur_anim=$(hyprctl getoption animations:enabled -j 2>/dev/null | jq -r '.bool // true')
    cur_direct=$(hyprctl getoption render:direct_scanout -j 2>/dev/null | jq -r '.int // 0')
    cur_tear=$(hyprctl getoption general:allow_tearing -j 2>/dev/null | jq -r '.bool // false')
    cur_opacity=$(grep -E '^opacity =' "$ALACRITTY_CONF" 2>/dev/null | tr -d ' ' || echo "opacity=0.30")

    if [ "$cur_blur" != "$SNAPSHOT_BLUR" ]; then
        echo "ASSERTION FAILED [$context]: blur mismatch (expected $SNAPSHOT_BLUR, got $cur_blur)" >&2
        return 1
    fi
    if [ "$cur_shadow" != "$SNAPSHOT_SHADOW" ]; then
        echo "ASSERTION FAILED [$context]: shadow mismatch (expected $SNAPSHOT_SHADOW, got $cur_shadow)" >&2
        return 1
    fi
    if [ "$cur_anim" != "$SNAPSHOT_ANIM" ]; then
        echo "ASSERTION FAILED [$context]: animations mismatch (expected $SNAPSHOT_ANIM, got $cur_anim)" >&2
        return 1
    fi
    if [ "$cur_direct" != "$SNAPSHOT_DIRECT" ]; then
        echo "ASSERTION FAILED [$context]: direct_scanout mismatch (expected $SNAPSHOT_DIRECT, got $cur_direct)" >&2
        return 1
    fi
    if [ "$cur_tear" != "$SNAPSHOT_TEAR" ]; then
        echo "ASSERTION FAILED [$context]: tearing mismatch (expected $SNAPSHOT_TEAR, got $cur_tear)" >&2
        return 1
    fi
    if [ "$cur_opacity" != "$SNAPSHOT_OPACITY" ]; then
        echo "ASSERTION FAILED [$context]: opacity mismatch (expected $SNAPSHOT_OPACITY, got $cur_opacity)" >&2
        return 1
    fi

    # Verify modes.json all active are false
    local active_count
    active_count=$(jq -r '[.active[] | select(. == true)] | length' "$MODES_JSON" 2>/dev/null || echo 0)
    if [ "$active_count" -ne 0 ]; then
        echo "ASSERTION FAILED [$context]: modes.json still has active modes: $(jq -c .active "$MODES_JSON")" >&2
        return 1
    fi

    echo "    ✓ [$context]: Verified perfect baseline return."
}

test_pair() {
    local a="$1"
    local b="$2"
    echo "--- [PAIR] ($a, $b) ---"

    # Order 1: Reverse off-order (on A -> on B -> off B -> off A)
    echo "  -> Reverse off-order: on $a -> on $b -> off $b -> off $a"
    bash "$MODE_CTL" set "$a" true
    sleep "$PACE"
    bash "$MODE_CTL" set "$b" true
    sleep "$PACE"
    bash "$MODE_CTL" set "$b" false
    sleep "$PACE"
    bash "$MODE_CTL" set "$a" false
    sleep "$PACE"
    assert_baseline "Pair ($a, $b) reverse off"

    # Order 2: Forward off-order (on A -> on B -> off A -> off B)
    echo "  -> Forward off-order: on $a -> on $b -> off $a -> off $b"
    bash "$MODE_CTL" set "$a" true
    sleep "$PACE"
    bash "$MODE_CTL" set "$b" true
    sleep "$PACE"
    bash "$MODE_CTL" set "$a" false
    sleep "$PACE"
    bash "$MODE_CTL" set "$b" false
    sleep "$PACE"
    assert_baseline "Pair ($a, $b) forward off"
}

test_triple() {
    local a="$1"
    local b="$2"
    local c="$3"
    echo "--- [TRIPLE] ($a, $b, $c) ---"

    # Order 1: Reverse off-order (on A -> on B -> on C -> off C -> off B -> off A)
    echo "  -> Reverse off-order: on $a -> on $b -> on $c -> off $c -> off $b -> off $a"
    bash "$MODE_CTL" set "$a" true
    sleep "$PACE"
    bash "$MODE_CTL" set "$b" true
    sleep "$PACE"
    bash "$MODE_CTL" set "$c" true
    sleep "$PACE"
    bash "$MODE_CTL" set "$c" false
    sleep "$PACE"
    bash "$MODE_CTL" set "$b" false
    sleep "$PACE"
    bash "$MODE_CTL" set "$a" false
    sleep "$PACE"
    assert_baseline "Triple ($a, $b, $c) reverse off"

    # Order 2: Forward off-order (on A -> on B -> on C -> off A -> off B -> off C)
    echo "  -> Forward off-order: on $a -> on $b -> on $c -> off $a -> off $b -> off $c"
    bash "$MODE_CTL" set "$a" true
    sleep "$PACE"
    bash "$MODE_CTL" set "$b" true
    sleep "$PACE"
    bash "$MODE_CTL" set "$c" true
    sleep "$PACE"
    bash "$MODE_CTL" set "$a" false
    sleep "$PACE"
    bash "$MODE_CTL" set "$b" false
    sleep "$PACE"
    bash "$MODE_CTL" set "$c" false
    sleep "$PACE"
    assert_baseline "Triple ($a, $b, $c) forward off"
}

MODES=("wallpaper-kill" "gaming" "power-saver" "coffee" "dnd")

echo ""
echo "[2] Running 10 Mode Pairs..."
pair_count=0
for ((i=0; i<${#MODES[@]}; i++)); do
    for ((j=i+1; j<${#MODES[@]}; j++)); do
        pair_count=$((pair_count + 1))
        echo "Pair #$pair_count:"
        test_pair "${MODES[i]}" "${MODES[j]}"
    done
done

echo ""
echo "[3] Running 10 Mode Triples..."
triple_count=0
for ((i=0; i<${#MODES[@]}; i++)); do
    for ((j=i+1; j<${#MODES[@]}; j++)); do
        for ((k=j+1; k<${#MODES[@]}; k++)); do
            triple_count=$((triple_count + 1))
            echo "Triple #$triple_count:"
            test_triple "${MODES[i]}" "${MODES[j]}" "${MODES[k]}"
        done
    done
done

echo ""
echo "=== Summary ==="
echo "Total Pairs Tested:   $pair_count (all reverse and forward off-orders passed)"
echo "Total Triples Tested: $triple_count (all reverse and forward off-orders passed)"
echo "=== All 20 Combinations and 40 Transitions Verified Successfully ==="
