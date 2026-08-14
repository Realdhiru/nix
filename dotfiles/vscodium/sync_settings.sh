#!/usr/bin/env bash
# Mirror VSCodium's live settings.json into the nix repo so edits stay
# reproducible. Writes go to the repo path, never back to the watched path,
# so no loop is possible: the watch is on the config directory and only
# "settings.json" events are acted on.
#
# Monitor mode (-m) on the whole dir, not one-shot re-arms on a file:
# rename-style saves (temp file + mv) replace the inode, and one-shot
# re-arming has a gap that silently drops events fired between instances.

set -euo pipefail

SRC_DIR="${HOME}/.config/VSCodium/User"
SRC="${SRC_DIR}/settings.json"
DST="${HOME}/nix/dotfiles/vscodium/settings.json"

if [[ ! -f "${SRC}" ]] || [[ ! -f "${DST}" ]]; then
    echo "vscodium-sync: missing source or target, exiting" >&2
    exit 1
fi

if ! command -v inotifywait >/dev/null 2>&1; then
    echo "vscodium-sync: inotifywait unavailable, polling every 15s" >&2
    while true; do
        prev="$(stat -c %Y "${SRC}" 2>/dev/null || echo 0)"
        sleep 15
        cur="$(stat -c %Y "${SRC}" 2>/dev/null || echo 0)"
        if [[ "${prev}" != "${cur}" ]] && python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "${SRC}" 2>/dev/null; then
            tmp="$(mktemp "${DST}.XXXXXX")"
            cp "${SRC}" "${tmp}"
            chmod 644 "${tmp}"
            mv -f "${tmp}" "${DST}"
        fi
    done
fi

inotifywait -m -q -e close_write -e moved_to --format '%f' "${SRC_DIR}" 2>/dev/null |
while read -r event; do
    if [[ "${event}" != "settings.json" ]]; then
        continue
    fi

    # Wait until the file is stable (mtime unchanged across a short interval)
    # before copying, so mid-write content is never mirrored.
    while true; do
        prev="$(stat -c %Y "${SRC}" 2>/dev/null || echo 0)"
        sleep 0.5
        cur="$(stat -c %Y "${SRC}" 2>/dev/null || echo 0)"
        if [[ "${prev}" == "${cur}" ]]; then
            break
        fi
    done

    # Only mirror valid JSON; empty/partial/broken content is never written
    # to the repo file, and the live file is left untouched.
    if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "${SRC}" 2>/dev/null; then
        tmp="$(mktemp "${DST}.XXXXXX")"
        cp "${SRC}" "${tmp}"
        chmod 644 "${tmp}"
        mv -f "${tmp}" "${DST}"
    else
        echo "vscodium-sync: skipped invalid JSON (empty or partial write)" >&2
    fi
done