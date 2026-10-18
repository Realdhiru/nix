---
title: Why NixOS Over Arch and Debian
tags: [philosophy, nixos, arch, debian, comparisons, system-architecture]
---

# Why NixOS Over Arch and Debian

When engineers build and showcase customized Linux environments, the overwhelming majority choose Arch Linux, with a minority on Fedora or Debian. We deliberately chose NixOS. 

This document outlines the concrete architectural reasons for this decision, the failure modes of traditional package managers, and the trade-offs encountered in practice.

---

## 1. The Core Problem with Imperative Package Managers

Traditional distributions (Arch, Debian, Ubuntu, Fedora) operate on an **accumulated state model**:

- You run `sudo pacman -S` or `sudo apt install`.
- Files are extracted directly into `/usr/bin`, `/usr/lib`, and `/etc`.
- Over months of development, configuration files are edited in-place, libraries are upgraded, unversioned dependencies are pulled via `pip` or `npm`, and configuration state drifts irreversibly.

### The Consequences
1. **Accidental State Drift**: Over time, your system enters an unrepeatable state. No two machines running `pacman -Syu` on different days end up with identical library ABIs or configurations.
2. **Broken Upgrades**: When an upstream update deprecates an ABI or introduces a regression in a window manager or audio stack, reverting is non-trivial and often requires manual chroot interventions.
3. **Hardware Loss Disaster**: If a machine suffers a hardware failure, recreating the exact desktop environment requires days of manual re-configuration, chasing forgotten dependencies, and hunting missing font configurations.

---

## 2. The Functional Packaging Model of NixOS

NixOS replaces imperative mutations with a **declarative, pure-functional model**:

$$\text{System} = f(\text{Configuration}, \text{Lockfile})$$

### How NixOS Eliminates the Failure Modes
- **Isolated Storage**: Packages are never dumped into `/usr/bin` or `/usr/lib`. Every single package, library, and configuration snippet lives under its own isolated cryptographic hash directory in `/nix/store/` (e.g. `/nix/store/7x9p...-hyprland-0.45.0`).
- **Atomic Generation Switching**: Rebuilding creates a new system generation by updating symlinks in `/nix/var/nix/profiles/system`. The switch from the old system to the new system is atomic.
- **Instant Bootloader Rollbacks**: If a newly built kernel or display driver fails to boot, you simply select the previous generation in `systemd-boot`. The prior system boots immediately because its entire dependency tree remains intact in the Nix Store.
- **Zero-Dependency Clones**: Cloning this repository onto an entirely new laptop and running `nixos-rebuild switch --flake .#nixos` produces the identical operating system, down to font rendering, udev rules, and audio equalizer curves.

---

## 3. Comparison Matrix

| Dimension | Arch Linux | Debian Stable | Our NixOS Setup |
| :--- | :--- | :--- | :--- |
| **State Paradigm** | Imperative, mutable | Imperative, mutable | **Declarative, immutable** |
| **Package Upgrades** | Rolling, uncoordinated | Infrequent, outdated software | **Rolling (nixpkgs-unstable) with atomic generation locks** |
| **System Rollback** | Requires snapshots (Btrfs) or manual package cache reverts | Complex manual downgrades | **Native generation rollback via bootloader or CLI** |
| **Multi-Version Coexistence**| Difficult; library collisions break packages | Difficult | **Trivial; multiple versions of libraries coexist peacefully** |
| **Configuration Centralization** | Fragmented across `/etc`, `~/.config`, and `/usr/share` | Fragmented | **Unified inside a single version-controlled git tree** |
| **Learning Curve** | Moderate | Low | **High; requires understanding functional programming and Nix DSL** |

---

## 4. Practical Observations and Trade-offs

### The Downside: The Packaging Friction
- In traditional Linux, you can download a standalone binary (or build from source with `make install`) and it runs immediately.
- In NixOS, standard ELF binaries expect dynamic linkers at `/lib64/ld-linux-x86-64.so.2`, which does not exist in standard NixOS paths. Binaries must either be packaged via Nix derivations, run through `buildFHSUserEnv`, patched via `autoPatchelfHook`, or executed using `appimage-run`.

### The Upside: The Confidence to Refactor
- In Arch or Debian, you hesitate to refactor your audio subsystem or display manager because you might break your daily work environment.
- In NixOS, we completely tore out `services.easyeffects` and replaced it with native PipeWire filter chains in a single commit, knowing with 100% mathematical certainty that if it failed, a single command would restore the previous working state.

## Related Nodes
- [[Why Flakes Over Legacy Nix Channels]]
- [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]]
- [[Home Manager vs System Configuration]]
