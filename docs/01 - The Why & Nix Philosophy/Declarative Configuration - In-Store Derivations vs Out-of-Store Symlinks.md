---
title: Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks
tags: [nix, architecture, home-manager, trade-offs, configuration-management]
---

# Declarative Configuration: In-Store Derivations vs Out-of-Store Symlinks

When deploying user-space dotfiles with Nix and Home Manager, there are fundamentally two opposing mechanisms available to bind a file into the filesystem:

1. **In-Store Derivations (Pure Declarative / Default Home Manager)**
2. **Out-of-Store Symlinks (`mkOutOfStoreSymlink`)**

Choosing between them is not merely an implementation detail; it defines how changes propagate, how rollback guarantees behave, and how fast you can iterate on user interface code.

---

## 1. Mechanism 1: In-Store Derivations

### How It Works
When you declare a file via standard Home Manager attributes:
```nix
xdg.configFile."hypr/hyprland.conf".source = ./hyprland.conf;
# or inline text:
xdg.configFile."brave-flags.conf".text = ''
  --ozone-platform-hint=wayland
'';
```
1. Nix takes the file contents and copies them into an immutable directory inside the Nix Store (`/nix/store/<hash>-hyprland.conf`).
2. Home Manager creates a symlink in your home directory pointing directly into the Nix Store:
   ```
   ~/.config/hypr/hyprland.conf -> /nix/store/7x9p...-hyprland.conf
   ```
3. The file inside `/nix/store/` is mounted strictly read-only (`mode 0444`).

### Core Advantages
- **Strict Reproducibility**: The exact byte sequence of that config file is tracked by the Nix generation and the git commit.
- **Atomic Rollbacks**: Rolling back via `nixos-rebuild switch --rollback` rolls back the configuration file to the exact byte state of that prior generation.
- **Isolation**: No external shell script or accidental editor save can alter the active configuration without going through Nix.

### Severe Downsides in Desktop Development
- **Iteration Latency**: Every single change—whether adjusting a 2px padding in QuickShell, changing a color variable in a theme, or testing a keybind—requires executing `nixos-rebuild switch` or `home-manager switch`.
- **Build Bottleneck**: Even with an empty rebuild, evaluating the flake, checking derivations, and linking files introduces a 30 to 60-second friction wall.
- **Read-Only Friction**: Opening the active config file in an editor displays `[Read-Only]`. Modifying it in-place requires manual `chmod` or editing the repository source and running a full rebuild cycle.

---

## 2. Mechanism 2: Out-of-Store Symlinks

### How It Works
Home Manager provides an escape hatch via `config.lib.file.mkOutOfStoreSymlink`:
```nix
xdg.configFile."hypr" = {
  source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/nix/dotfiles/hypr";
  force = true;
};
```
1. Nix does **not** copy the files into `/nix/store/`.
2. Home Manager creates a symlink pointing directly to your live, mutable git repository:
   ```
   ~/.config/hypr -> /home/realdhiru/nix/dotfiles/hypr
   ```
3. The destination is a regular user directory with standard read-write permissions.

### Core Advantages
- **Instantaneous Iteration (0-second propagation)**: Editing a QML file, Lua module, or Wallust template in `~/nix/dotfiles/` immediately updates the active config. Hitting `SUPER + R` reloads Hyprland and QuickShell in ~15ms.
- **Developer Flow**: Eliminates context switching and wait times while styling widgets, tweaking window rules, and tuning animations.
- **Declarative Provisioning**: A fresh machine cloned from git automatically establishes all live pointers on the very first rebuild.

### Trade-offs & Risks
- **Impurity / External State**: If uncommitted edits in `~/nix/dotfiles/` introduce a syntax error, rolling back the NixOS generation at the bootloader will **not** revert the modified files in your home directory.
- **Path Rigidity**: Requires the git repository to reside in a predictable, stable path (parameterized cleanly via `config.home.homeDirectory`).

---

## 3. The Hybrid Strategy Used in Our System

Rather than dogmatically choosing one over the other, our architecture applies each mechanism where its strengths dominate:

| Configuration Area | Applied Mechanism | Engineering Rationale |
| :--- | :--- | :--- |
| **QuickShell QML Widgets (`dotfiles/hypr/scripts/quickshell`)** | Out-of-Store Symlink | Rapid visual prototyping, layout tuning, and live QML reloads. |
| **Hyprland Lua Modules (`dotfiles/hypr/*.lua`)** | Out-of-Store Symlink | Hot-reloading keybinds, window rules, and opacity layers in ~15ms. |
| **Wallust Theming & Templates (`dotfiles/wallust`)** | Out-of-Store Symlink | Real-time color generation triggered on wallpaper switch. |
| **Hardware & Kernel Drivers (`hosts/nixos/`)** | In-Store Derivation | Pure immutable root control; boot stability is non-negotiable. |
| **System Packages (`modules/system/packages.nix`)** | In-Store Derivation | Exact binary closures, shared libraries, and dependencies. |
| **MPV MPRIS Plugin Link (`home.nix`)** | In-Store Reference | Declaratively tied to `${pkgs.mpvScripts.mpris}` to survive garbage collection. |
| **Hardware Video Flags (`brave-flags.conf`)** | In-Store Derivation | Static text generated declaratively; no live developer iteration needed. |

---

## 4. Key Takeaways for Technical Demos

- **The Trade-off**: In-store derivations give perfect immutability at the cost of slow iteration; out-of-store symlinks give instant live iteration at the cost of decoupling config changes from git-generation rollbacks.
- **The Pragmatic Balance**: Keep the kernel, system services, and package sets in-store for rock-solid stability; link the interactive UI layer out-of-store so you never wait for a rebuild just to tweak a user interface.

## Related Nodes
- [[The Out-of-Store Symlink Paradigm]]
- [[Home Manager vs System Configuration]]
- [[Flake & System Architecture MOC]]
