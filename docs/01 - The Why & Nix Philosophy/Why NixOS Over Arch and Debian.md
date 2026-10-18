---
title: Why NixOS Over Arch and Debian
tags: [philosophy, nixos, arch, debian, comparisons, system-architecture]
---

# Why NixOS Over Arch and Debian

When engineers build and showcase customized Linux environments, the overwhelming majority choose Arch Linux, with a minority on Fedora or Debian. We deliberately chose NixOS. 

This page records why this particular machine uses NixOS and the practical tradeoffs observed in this configuration. It is not a general distribution comparison guide.

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
- **Store-Based Packages**: Nix package outputs and their dependencies live at versioned paths in `/nix/store/`; the system exposes selected programs through profiles and generated system paths. Not every configuration file is an independent store object.
- **Generation-Based System Changes**: Rebuilding creates a new system generation and updates system/profile references. A prior generation can remain bootable while retained, but service side effects and mutable user/system data are not transactionally rolled back.
- **Generation Rollback**: A retained previous generation can be selected from the boot menu or activated from a working system. It restores the declared system closure, while mutable user data and service side effects remain outside that rollback.
- **Reconstructable Configuration**: This repository describes the intended software and desktop configuration. Rebuilding it on compatible hardware with the declared inputs can reconstruct that environment; host hardware, architecture, external state, and mutable user data still differ.

---

## 3. Comparison Matrix

| Dimension | Arch Linux | Debian Stable | Our NixOS Setup |
| :--- | :--- | :--- | :--- |
| **State Paradigm** | Imperative, mutable | Imperative, mutable | **Declarative, immutable** |
| **Package Upgrades** | Rolling, uncoordinated | Infrequent, outdated software | **Pinned nixpkgs inputs with generation-based activation** |
| **System Rollback** | Requires snapshots (Btrfs) or manual package cache reverts | Complex manual downgrades | **Native generation rollback via bootloader or CLI** |
| **Multi-Version Coexistence**| Difficult; library collisions break packages | Difficult | **Trivial; multiple versions of libraries coexist peacefully** |
| **Configuration Centralization** | Fragmented across `/etc`, `~/.config`, and `/usr/share` | Fragmented | **Unified inside a single version-controlled git tree** |
| **Learning Curve** | Moderate | Low | **High; requires understanding functional programming and Nix DSL** |

---

## 4. Practical Observations and Trade-offs

### The Downside: The Packaging Friction
- In traditional Linux, you can download a standalone binary (or build from source with `make install`) and it runs immediately.
- In NixOS, standard ELF binaries expect dynamic linkers at `/lib64/ld-linux-x86-64.so.2`, which does not exist in standard NixOS paths. Binaries must either be packaged via Nix derivations, run through `buildFHSUserEnv`, patched via `autoPatchelfHook`, or executed using `appimage-run`.
- **Learning cost:** Nix replaces familiar imperative steps with a language, module system, evaluation, and derivations. It rewards explicit, reproducible configuration, but takes time to learn and can make quick one-off changes less obvious.

### The Upside: The Confidence to Refactor
- In Arch or Debian, you hesitate to refactor your audio subsystem or display manager because you might break your daily work environment.
- NixOS generations make system changes easier to test and recover from, but do not make every change risk-free: mutable user data and out-of-store configuration are outside generation rollback.
- In this system, the audio stack was refactored from `services.easyeffects` to native PipeWire filter chains; a prior generation remained available as a recovery path.

### Scope of reproducibility
- This system uses a lockfile to pin declared inputs. Reproducibility applies to the declared software environment under matching platform assumptions; it does not make different hardware or mutable state identical.

## Related Nodes
- [[Why Flakes Over Legacy Nix Channels]]
- [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]]
- [[Home Manager vs System Configuration]]
