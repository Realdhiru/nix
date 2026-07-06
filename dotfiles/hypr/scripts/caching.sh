#!/usr/bin/env bash

export QS_CACHE_DIR="$HOME/.cache/quickshell"
export QS_STATE_DIR="$HOME/.local/state/quickshell"
export QS_RUN_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell"
export QS_LOG_DIR="$QS_RUN_DIR/logs"

mkdir -p "$QS_CACHE_DIR" "$QS_STATE_DIR" "$QS_RUN_DIR" "$QS_LOG_DIR"

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
QS_DIR="$SCRIPT_DIR/quickshell"

qs_ensure_cache() {
    local WIDGET_NAME="$1"
    
    # Native bash uppercase conversion (zero subshells, infinitely faster)
    local WIDGET_UPPER="${WIDGET_NAME^^}"
    
    local WIDGET_CACHE="$QS_CACHE_DIR/$WIDGET_NAME"
    local WIDGET_STATE="$QS_STATE_DIR/$WIDGET_NAME"
    local WIDGET_RUN="$QS_RUN_DIR/$WIDGET_NAME"
    
    mkdir -p "$WIDGET_CACHE" "$WIDGET_STATE" "$WIDGET_RUN"
    
    export "QS_CACHE_${WIDGET_UPPER}=$WIDGET_CACHE"
    export "QS_STATE_${WIDGET_UPPER}=$WIDGET_STATE"
    export "QS_RUN_${WIDGET_UPPER}=$WIDGET_RUN"
}

if [[ -d "$QS_DIR" ]]; then
    # Enable safe globbing to prevent wildcard literal resolution
    shopt -s nullglob
    for dir in "$QS_DIR"/*/; do
        WIDGET_NAME=$(basename "${dir%/}")
        qs_ensure_cache "$WIDGET_NAME"
    done
    shopt -u nullglob
fi