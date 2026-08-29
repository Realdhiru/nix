{ config, pkgs, ... }:

let
  liquifyThemeSrc = pkgs.fetchFromGitHub {
    owner = "NMWplays";
    repo = "Liquify";
    rev = "69dbb54495fb2217838d3bfbb6fdbae4e4d30b00";
    hash = "sha256-+/uJFp834gK2EiJO9rWOJMcRIXtLroUzV9C1dMhggvM=";
  };

  marketplaceSrc = pkgs.fetchzip {
    url = "https://github.com/spicetify/marketplace/releases/download/v1.0.10/marketplace.zip";
    hash = "sha256-WgErEKALKg8XCx2jx3gigYhBVRL5ncrJZjVa1Dnfp7w=";
  };
in
{
  home.packages = with pkgs; [
    spotify
    spicetify-cli
  ];

  # Create the user wrapper and sync scripts
  home.file.".local/bin/spotify-sync" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      SPOTIFY_STORE_PATH="$(readlink -f "${pkgs.spotify}/share/spotify")"
      CLIENT_DIR="$HOME/.local/share/spotify-client"
      VERSION_FILE="$CLIENT_DIR/.nix-version"

      mkdir -p "$CLIENT_DIR"
      mkdir -p "$HOME/.config/spicetify/Themes"
      mkdir -p "$HOME/.config/spicetify/Extensions"
      mkdir -p "$HOME/.config/spicetify/CustomApps"

      # Seed Liquify theme if not present
      if [ ! -d "$HOME/.config/spicetify/Themes/Liquify" ]; then
        echo "Seeding Liquify theme to ~/.config/spicetify/Themes/Liquify..."
        cp -rfL "${liquifyThemeSrc}" "$HOME/.config/spicetify/Themes/Liquify"
        chmod -R u+w "$HOME/.config/spicetify/Themes/Liquify"
      fi

      # Seed custom extensions if not present
      if [ -d "${./spicetify}" ]; then
        for ext in "${./spicetify}"/*; do
          ext_name="$(basename "$ext")"
          if [ ! -f "$HOME/.config/spicetify/Extensions/$ext_name" ]; then
            cp -fL "$ext" "$HOME/.config/spicetify/Extensions/$ext_name"
            chmod u+w "$HOME/.config/spicetify/Extensions/$ext_name"
          fi
        done
      fi

      # Seed Marketplace if not present
      if [ ! -d "$HOME/.config/spicetify/CustomApps/marketplace" ]; then
        echo "Seeding Spicetify Marketplace to ~/.config/spicetify/CustomApps/marketplace..."
        mkdir -p "$HOME/.config/spicetify/CustomApps/marketplace"
        if [ -d "${marketplaceSrc}/marketplace-dist" ]; then
          cp -rfL "${marketplaceSrc}/marketplace-dist/"* "$HOME/.config/spicetify/CustomApps/marketplace/"
        else
          cp -rfL "${marketplaceSrc}/"* "$HOME/.config/spicetify/CustomApps/marketplace/"
        fi
        chmod -R u+w "$HOME/.config/spicetify/CustomApps/marketplace"
      fi

      # Sync Spotify binaries if Nix store package updated
      CURRENT_VERSION=""
      if [ -f "$VERSION_FILE" ]; then
        CURRENT_VERSION="$(cat "$VERSION_FILE" 2>/dev/null || true)"
      fi

      if [ "$CURRENT_VERSION" != "$SPOTIFY_STORE_PATH" ] || [ ! -f "$CLIENT_DIR/spotify" ]; then
        echo "Syncing Spotify base files from $SPOTIFY_STORE_PATH..."
        cp -rfL "$SPOTIFY_STORE_PATH/"* "$CLIENT_DIR/"
        chmod -R u+w "$CLIENT_DIR"
        echo "$SPOTIFY_STORE_PATH" > "$VERSION_FILE"

        # Apply initial spicetify configuration if needed
        if command -v spicetify >/dev/null 2>&1; then
          spicetify config spotify_path "$CLIENT_DIR" 2>/dev/null || true
          spicetify config prefs_path "$HOME/.config/spotify/prefs" 2>/dev/null || true

          # Initialize config if newly created
          if [ ! -f "$HOME/.config/spicetify/config-xpui.ini" ]; then
            spicetify config current_theme Liquify 2>/dev/null || true
            spicetify config extensions lyrics-raf-fallback.js 2>/dev/null || true
            spicetify config extensions liquify-config-seed.js 2>/dev/null || true
            spicetify config custom_apps marketplace 2>/dev/null || true
          fi

          echo "Applying Spicetify patch..."
          spicetify backup apply 2>/dev/null || spicetify apply 2>/dev/null || true
        fi
      fi
    '';
  };

  home.file.".local/bin/spotify-wrapper" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      "$HOME/.local/bin/spotify-sync"
      exec "$HOME/.local/share/spotify-client/spotify" "$@"
    '';
  };

  # Override standard desktop entry to point to our user wrapper
  xdg.desktopEntries.spotify = {
    name = "Spotify";
    genericName = "Music Player";
    exec = "${config.home.homeDirectory}/.local/bin/spotify-wrapper %U";
    icon = "spotify-client";
    terminal = false;
    categories = [ "Audio" "Music" "Player" "AudioVideo" ];
    mimeType = [ "x-scheme-handler/spotify" ];
  };
}