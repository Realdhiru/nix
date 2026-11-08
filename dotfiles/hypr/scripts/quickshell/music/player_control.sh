#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "music"

SEEK_FILE="$QS_RUN_MUSIC/seek_data"
SEEK_LOCK="$QS_RUN_MUSIC/seek.lock"
WORKER_PID="$QS_RUN_MUSIC/seek.pid"

run_seek_worker() {
    exec 9>"$SEEK_LOCK"
    flock -x 9
    while :; do
        if [[ ! -s "$SEEK_FILE" ]]; then
            rm -f "$WORKER_PID"
            exit 0
        fi
        IFS=$'\t' read -r seek_percent length player < "$SEEK_FILE" || true
        rm -f "$SEEK_FILE"
        flock -u 9

        if [[ "$length" =~ ^[0-9]+([.][0-9]+)?$ && "$seek_percent" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            target=$(awk -v len="$length" -v pct="$seek_percent" 'BEGIN { printf "%.2f", len * pct / 100 }')
            timeout 3 playerctl -p "$player" position "$target" >/dev/null 2>&1 || true
        fi

        flock -x 9
    done
}

command_name="${1:-}"
arg="${2:-}"
length="${3:-}"
player="${4:-}"

if [[ "$command_name" == seek ]]; then
    if [[ -z "$player" ]]; then
        player=$(timeout 2 playerctl status -f '{{playerName}}' 2>/dev/null | head -n 1 || true)
    fi
    [[ -n "$player" ]] || exit 0

    exec 9>"$SEEK_LOCK"
    flock -x 9
    tmp=$(mktemp "$QS_RUN_MUSIC/seek.XXXXXX")
    printf '%s\t%s\t%s\n' "$arg" "$length" "$player" > "$tmp"
    mv -f -- "$tmp" "$SEEK_FILE"
    if [[ ! -s "$WORKER_PID" ]] || ! kill -0 "$(<"$WORKER_PID")" 2>/dev/null; then
        rm -f "$WORKER_PID"
        ( exec 9>&-; "$0" --seek-worker ) </dev/null >/dev/null 2>&1 &
        printf '%s\n' "$!" > "$WORKER_PID"
    fi
    exit 0
fi

if [[ "$command_name" == --seek-worker ]]; then
    run_seek_worker
    exit 0
fi

if [[ -z "$player" ]]; then
    player=$(timeout 2 playerctl status -f '{{playerName}}' 2>/dev/null | head -n 1 || true)
fi
[[ -n "$player" ]] || exit 0

case "$command_name" in
    next) timeout 3 playerctl -p "$player" next ;;
    prev) timeout 3 playerctl -p "$player" previous ;;
    play-pause) timeout 3 playerctl -p "$player" play-pause ;;
esac
