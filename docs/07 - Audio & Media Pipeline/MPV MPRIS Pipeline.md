---
title: MPV MPRIS Pipeline
tags: [media, mpv, mpris, dbus, quickshell, declarations]
---

# MPV MPRIS Pipeline: Declarative Desktop Media Tracking

MPV is our default hardware-accelerated media player. By default, standalone MPV does not broadcast **MPRIS D-Bus signals** (`org.mpris.MediaPlayer2.mpv`).

Without MPRIS integration, QuickShell cannot display track titles, artist names, album art, or playback progress in the TopBar or Music Popup.

---

## 1. The Declarative Packaging Trap in NixOS

On traditional distributions, you download `mpris.so` and drop it into `~/.config/mpv/scripts/`.

In NixOS, hardcoding a store path into a dotfile creates a trap: when `nix-collect-garbage` purges older system generations, that store path is deleted, and MPV fails on next launch.

---

## 2. The Multi-Tier Declarative Solution

We resolve this cleanly across two declarative layers:

1. **System Override** (`modules/system/packages.nix`):
   ```nix
   (mpv.override { scripts = [ mpvScripts.mpris ]; })
   ```
2. **Home Manager Declarative Symlink** (`home.nix`):
   ```nix
   xdg.configFile."mpv/scripts/mpris.so" = {
     source = "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";
     force = true;
   };
   ```

Whenever the system generation is upgraded, Home Manager atomically repoints the symlink to the active package derivation. QuickShell's `MusicState.qml` singleton tracks local media playback seamlessly.

## Related Nodes
- [[Native PipeWire 10-Band Equalizer]]
- [[TopBar & Dynamic Workspaces]]
- [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]]
