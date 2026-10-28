#!/usr/bin/env bash
# scripts/selftest-modes.sh
# Agent-run only test suite for mode state machine verification.
# Adheres to AGENTS.md rule: >=1.5s GPU pacing between agent test steps.
# Verifies order independence across mode pairs asserting full return to baseline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE_CTL="$ROOT_DIR/dotfiles/hypr/scripts/mode_ctl.sh"
DESKTOP_STATE_DIR="${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}"
MODES_JSON="$DESKTOP_STATE_DIR/modes/modes.json"
ALACRITTY_CONF="$HOME/.cache/theme/alacritty-colors.toml"

echo "=== Mode State Machine Self-Test Suite ==="

# 1. Snapshot baseline
echo "[1/4] Snapshotting baseline compositor and mode state..."
SNAPSHOT_BLUR=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | jq -r '.bool // true')
SNAPSHOT_SHADOW=$(hyprctl getoption decoration:shadow:enabled -j 2>/dev/null | jq -r '.bool // true')
SNAPSHOT_ANIM=$(hyprctl getoption animations:enabled -j 2>/dev/null | jq -r '.bool // true')
SNAPSHOT_DIRECT=$(hyprctl getoption render:direct_scanout -j 2>/dev/null | jq -r '.int // 0')
SNAPSHOT_TEAR=$(hyprctl getoption general:allow_tearing -j 2>/dev/null | jq -r '.bool // false')
SNAPSHOT_OPACITY=$(grep -E '^opacity =' "$ALACRITTY_CONF" 2>/dev/null | tr -d ' ' || echo "opacity=0.30")
SNAPSHOT_MODES=$(cat "$MODES_JSON" 2>/dev/null || echo "{}")

echo "  Baseline: blur=$SNAPSHOT_BLUR, shadow=$SNAPSHOT_SHADOW, anim=$SNAPSHOT_ANIM, direct_scanout=$SNAPSHOT_DIRECT, tearing=$SNAPSHOT_TEAR, $SNAPSHOT_OPACITY"

assert_baseline() {
    local context="$1"
    local cur_blur cur_shadow cur_anim cur_direct cur_tear cur_opacity cur_modes
    cur_blur=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null | jq -r '.bool // true')
    cur_shadow=$(hyprctl getoption decoration:shadow:enabled -j 2>/dev/null | jq -r '.bool // true')
    cur_anim=$(hyprctl getoption animations:enabled -j 2>/dev/null | jq -r '.bool // true')
    cur_direct=$(hyprctl getoption render:direct_scanout -j 2>/dev/null | jq -r '.int // 0')
    cur_tear=$(hyprctl getoption general:allow_tearing -j 2>/dev/null | jq -r '.bool // false')
    cur_opacity=$(grep -E '^opacity =' "$ALACRITTY_CONF" 2>/dev/null | tr -d ' ' || echo "opacity=0.30")
    cur_modes=$(cat "$MODES_JSON" 2>/dev/null || echo "{}")

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

    echo "  -> Assertion OK [$context]: Returned perfectly to baseline."
}

test_pair() {
    local a="$1"
    local b="$2"
    echo "--- Testing Pair: ($a, $b) ---"

    # Sequence 1: on A -> on B -> off A -> off B
    echo "  [Seq 1] on $a -> on $b -> off $a -> off $b"
    bash "$MODE_CTL" set "$a" true
    sleep 1.6
    bash "$MODE_CTL" set "$b" true
    sleep 1.6
    bash "$MODE_CTL" set "$a" false
    sleep 1.6
    bash "$MODE_CTL" set "$b" false
    sleep 1.6
    assert_baseline "Seq 1: ($a, $b) on-A on-B off-A off-B"

    # Sequence 2: on A -> on B -> off B -> off A
    echo "  [Seq 2] on $a -> on $b -> off $b -> off $a"
    bash "$MODE_CTL" set "$a" true
    sleep 1.6
    bash "$MODE_CTL" set "$b" true
    sleep 1.6
    bash "$MODE_CTL" set "$b" false
    sleep 1.6
    bash "$MODE_CTL" set "$a" false
    sleep 1.6
    assert_baseline "Seq 2: ($a, $b) on-A on-B off-B off-A"
}

# Run pair tests across visual-affecting modes
test_pair "wallpaper-kill" "gaming"
test_pair "gaming" "power-saver"
test_pair "wallpaper-kill" "power-saver"
test_pair "gaming" "coffee"

echo "=== All Mode State Machine Self-Tests Passed Successfully ==="
