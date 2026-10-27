#!/usr/bin/env bash
# gameclean - find and delete wine/lutris/proton game leftover files.
set -euo pipefail

APPLY=0
QUIET=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y) APPLY=1; shift ;;
        -q) QUIET=1; shift ;;
        *) shift ;;
    esac
done

HOME_DIR="${HOME:-/home/realdhiru}"
GAMES="$HOME_DIR/Games"
PREFIXES="$GAMES/prefixes"
LUTRIS_GAMES="$HOME_DIR/.local/share/lutris/games"
UMU_PREFIX="$GAMES/umu/umu-default"
CACHE="$HOME_DIR/.cache"

CACHE_DIRS=(
    "lutris" "winetricks" "umu" "rpcs3" "dxvk" "dxvk-cache"
    "vkd3d" "winelib" "gamescope" "wine" "steam"
)

human() {
    local bytes="$1"
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$(( (bytes + 1023) / 1024 ))K"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$(( (bytes + 1048575) / 1048576 ))M"
    else
        awk -v b="$bytes" 'BEGIN { printf "%.1fG", b / 1073741824 }'
    fi
}

get_size() {
    local target="$1"
    if [ -e "$target" ]; then
        du -sb "$target" 2>/dev/null | awk '{print $1}' || echo 0
    else
        echo 0
    fi
}

declare -a ORPHAN_PATHS=()
declare -a ORPHAN_REASONS=()
declare -A REFERENCED_PREFIXES=()
declare -A REFERENCED_ROOTS=()

# 1+2+5: check lutris entries for broken installs
if [ -d "$LUTRIS_GAMES" ]; then
    shopt -s nullglob
    for yml in "$LUTRIS_GAMES"/*.yml; do
        game_exe=$(grep -E '^[[:space:]]*(exe|main_file|game_dir):' "$yml" 2>/dev/null | head -n 1 | sed -E 's/^[[:space:]]*(exe|main_file|game_dir):[[:space:]]*//' | sed 's/\\ / /g' || true)
        prefix_val=$(grep -E '^[[:space:]]*prefix:' "$yml" 2>/dev/null | head -n 1 | sed -E 's/^[[:space:]]*prefix:[[:space:]]*//' | sed 's/\\ / /g' || true)

        root_dir=""
        if [ -n "$game_exe" ]; then
            root_dir=$(dirname "$game_exe")
        fi

        if [ -n "$prefix_val" ] && [ -d "$prefix_val" ]; then
            real_p=$(realpath "$prefix_val" 2>/dev/null || echo "$prefix_val")
            REFERENCED_PREFIXES["$real_p"]=1
        fi

        if [ -n "$root_dir" ] && [ -d "$root_dir" ]; then
            real_r=$(realpath "$root_dir" 2>/dev/null || echo "$root_dir")
            REFERENCED_ROOTS["$real_r"]=1
        else
            ORPHAN_PATHS+=("$yml")
            ORPHAN_REASONS+=("lutris entry points to deleted game files")
        fi
    done
    shopt -u nullglob
fi

# any prefixes left over that no lutris entry references
if [ -d "$PREFIXES" ]; then
    for p in "$PREFIXES"/*; do
        if [ -d "$p" ]; then
            real_p=$(realpath "$p" 2>/dev/null || echo "$p")
            if [ -z "${REFERENCED_PREFIXES[$real_p]:-}" ]; then
                ORPHAN_PATHS+=("$p")
                ORPHAN_REASONS+=("orphan wine prefix (no game references it)")
            fi
        fi
    done
fi

# any prefix dirs created in product folders anywhere under ~/Games
if [ -d "$GAMES" ]; then
    for c in "$GAMES"/*/drive_c; do
        if [ -d "$c" ]; then
            base=$(dirname "$c")
            if [ "$base" != "$UMU_PREFIX" ]; then
                ORPHAN_PATHS+=("$base")
                ORPHAN_REASONS+=("stray wine prefix inside game folder")
            fi
        fi
    done
fi

# 3: umu/proton prefix temp + shadercache junk
if [ -d "$UMU_PREFIX" ]; then
    for name in "Temp" "shadercache" "temp" "WineShaders" "Shaders"; do
        p="$UMU_PREFIX/drive_c/users/steamuser/AppData/Local/$name"
        if [ -d "$p" ]; then
            ORPHAN_PATHS+=("$p")
            ORPHAN_REASONS+=("wine temp/shadercache inside umu prefix")
        fi
    done
    for extra in "$UMU_PREFIX/shadercache" "$UMU_PREFIX/CaseShaderCache"; do
        if [ -d "$extra" ]; then
            ORPHAN_PATHS+=("$extra")
            ORPHAN_REASONS+=("proton shadercache")
        fi
    done
fi

# 4: game caches
for name in "${CACHE_DIRS[@]}"; do
    p="$CACHE/$name"
    if [ -d "$p" ]; then
        ORPHAN_PATHS+=("$p")
        ORPHAN_REASONS+=("game-related cache")
    fi
done

TOTAL=0
declare -a SIZES=()
for ((i=0; i<${#ORPHAN_PATHS[@]}; i++)); do
    sz=$(get_size "${ORPHAN_PATHS[i]}")
    SIZES+=("$sz")
    TOTAL=$((TOTAL + sz))
done

TOTAL_HUMAN=$(human "$TOTAL")

if [ "$QUIET" -eq 1 ]; then
    if [ "$APPLY" -eq 1 ]; then
        echo "$TOTAL_HUMAN"
    fi
else
    echo "gameclean — total to delete: $TOTAL_HUMAN"
    echo ""
    for ((i=0; i<${#ORPHAN_PATHS[@]}; i++)); do
        p="${ORPHAN_PATHS[i]}"
        reason="${ORPHAN_REASONS[i]}"
        sz="${SIZES[i]}"
        sz_h=$(human "$sz")
        printf "  %-7s  %s\n        %s\n" "$sz_h" "$reason" "$p"
    done
    echo ""
    if [ "${#ORPHAN_PATHS[@]}" -eq 0 ]; then
        echo "Nothing to clean."
    fi
fi

if [ "$APPLY" -eq 1 ] && [ "${#ORPHAN_PATHS[@]}" -gt 0 ]; then
    for p in "${ORPHAN_PATHS[@]}"; do
        rm -rf "$p" 2>/dev/null || echo "failed: $p" >&2
    done
    echo "Deleted. Freed $TOTAL_HUMAN."
elif [ "$APPLY" -eq 0 ]; then
    echo "(preview only — run:  gameclean -y   to actually delete)"
fi
