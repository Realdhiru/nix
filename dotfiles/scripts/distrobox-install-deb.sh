#!/usr/bin/env bash
set -euo pipefail

BOX_NAME="deb-box"
CONTAINER_IMAGE="docker.io/library/debian:bookworm-slim"

notify() {
    local title="$1"
    local msg="$2"
    local urgency="${3:-normal}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" "$title" "$msg"
    fi
}

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-deb-file>"
    exit 1
fi

DEB_PATH="$(realpath "$1")"
if [ ! -f "$DEB_PATH" ]; then
    notify "Distrobox Install" "File not found: $DEB_PATH" "critical"
    exit 1
fi

notify "Distrobox (.deb)" "Preparing container '$BOX_NAME'..."

# Create container if it doesn't exist yet
if ! distrobox list --no-color 2>/dev/null | grep -q "[[:space:]]${BOX_NAME}[[:space:]]"; then
    notify "Distrobox (.deb)" "Initializing minimal Debian container (one-time setup)..."
    distrobox create --name "$BOX_NAME" --image "$CONTAINER_IMAGE" --yes
    distrobox enter "$BOX_NAME" -- bash -c "
        sudo apt-get update -qq && \
        sudo apt-get install -y --no-install-recommends zenity xdg-utils libgl1-mesa-dri fonts-noto fonts-noto-cjk fonts-liberation fonts-dejavu fontconfig && \
        fc-cache -f && \
        echo 'ELECTRON_OZONE_PLATFORM_HINT=auto' | sudo tee -a /etc/environment && \
        sudo tee /usr/local/bin/distrobox-host-wrapper >/dev/null << 'EOF'
#!/bin/sh
exec distrobox-host-exec \"\$(basename \"\$0\")\" \"\$@\"
EOF
        sudo chmod +x /usr/local/bin/distrobox-host-wrapper && \
        for cmd in nix nixos-rebuild rebuild hyprctl journalctl systemctl git; do
            sudo ln -sf /usr/local/bin/distrobox-host-wrapper /usr/local/bin/\$cmd
        done
    "
fi

# Ensure debian-side apt dependencies are available
notify "Distrobox (.deb)" "Installing $(basename "$DEB_PATH")..."

# Run apt inside distrobox
distrobox enter "$BOX_NAME" -- bash -c "
    sudo apt-get update -qq && \
    sudo apt-get install -y --no-install-recommends '$DEB_PATH'
"

# Detect desktop files provided by this package
DEB_PKG_NAME="$(basename "$DEB_PATH" | cut -d'_' -f1)"

# Export all desktop apps or binaries and ensure zero-idle cleanup
distrobox enter "$BOX_NAME" -- bash -c "
    DESKTOP_FILES=\$(dpkg -L '$DEB_PKG_NAME' 2>/dev/null | grep -E '/usr/share/applications/.*\.desktop\$' || true)
    if [ -n \"\$DESKTOP_FILES\" ]; then
        for df in \$DESKTOP_FILES; do
            app_name=\$(basename \"\$df\" .desktop)
            distrobox-export --app \"\$app_name\" || true
        done
    else
        distrobox-export --bin \"/usr/bin/$DEB_PKG_NAME\" --export-path ~/.local/bin || true
    fi
"

# Patch exported .desktop: sanitize MIME types, run with Wayland flags, and safe Exec wrapper
for df in ~/.local/share/applications/${BOX_NAME}-*.desktop; do
    [ -f "$df" ] || continue

    # Strip dangerous/unintended MIME types (HTTP/HTTPS/HTML and generic document formats)
    if grep -q "^MimeType=" "$df"; then
        sed -i -E 's|x-scheme-handler/https?;||g' "$df"
        sed -i -E 's|text/html;||g' "$df"
        sed -i -E 's|application/vnd\.ms-[^;]+;||g' "$df"
        sed -i -E 's|application/vnd\.openxmlformats-[^;]+;||g' "$df"
        sed -i -E 's|text/(csv|tab-separated-values);||g' "$df"
        # If MimeType is now empty, remove the line
        sed -i -E '/^MimeType=;?$/d' "$df"
    fi

    # Safe Exec wrapper: pass %U as positional argument, avoiding EOF parse errors on complex URLs
    if ! grep -q "distrobox stop" "$df"; then
        sed -i -E 's|Exec=(.*)|Exec=sh -c '\''ELECTRON_OZONE_PLATFORM_HINT=auto "$@" ; /run/current-system/sw/bin/distrobox stop '"$BOX_NAME"' --yes >/dev/null 2>\&1 \&'\'' -- \1|g' "$df"
    fi
done

# Synchronize desktop database to immediately purge hijacked MIME cache
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database ~/.local/share/applications/ >/dev/null 2>&1 || true
fi

notify "Distrobox (.deb)" "Successfully installed '$DEB_PKG_NAME'! Added to app launcher."
