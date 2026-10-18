---
title: The Out-of-Store Symlink Paradigm
tags: [nix, symlinks, home-manager, fast-iteration, dotfiles]
---

# The Out-of-Store Symlink Paradigm: Solving the Live Ricing Latency Barrier

If you ask custom desktop developers why they hesitate to adopt NixOS, the complaint is almost universal:

> "Every time I adjust a 2px padding in my bar or tweak a color in my terminal, I have to wait 45 seconds for `nixos-rebuild switch` to copy files into `/nix/store`."

This is the classic friction point between functional package management and rapid UI development. This document details how we bypassed this bottleneck.

---

## 1. The Bottleneck: Nix Store Immutability vs Rapid UI Development

Under standard Home Manager configurations, dotfiles are copied into read-only derivations inside the Nix store:
```
~/.config/hypr/hyprland.lua -> /nix/store/xyz...-home-manager-files/.config/hypr/hyprland.lua (mode 0444)
```
- Opening that file in any editor flags it as `[Read-Only]`.
- Modifying your desktop requires editing the file inside your repository, then running `nixos-rebuild switch` and waiting for evaluation.
- For rapid visual prototyping—where an engineer might adjust margins, opacity values, and animations dozens of times per hour—this friction makes iterative ricing impractical.

---

## 2. The Solution: `mkOutOfStoreSymlink`

In `home.nix`, we decouple the interactive UI layer from the Nix Store using Home Manager's out-of-store symlink primitive:

```nix
xdg.configFile."hypr" = {
  source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/nix/dotfiles/hypr";
  force = true;
};
```

### Key Functional Properties
1. **0-Second Iteration**: When editing a QML widget, Lua module, or Wallust color template in `~/nix/dotfiles/`, the live configuration updates immediately.
2. **Instant Hot-Reloading**: Executing `reload.sh` (`SUPER + R`) reloads Hyprland and refreshes QuickShell in ~15ms without unmapping Wayland surfaces.
3. **Declarative Initial Provisioning**: On a fresh machine, Home Manager automatically establishes all live symlinks pointing to the cloned git repository on the first build.

For an exhaustive architectural comparison between this approach and pure in-store derivations, see [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]].

## Related Nodes
- [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]]
- [[Home Manager vs System Configuration]]
- [[QuickShell Event-Driven IPC]]
- [[Lua Configuration Model]]
