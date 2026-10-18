---
title: Flake & System Architecture Map of Content
type: moc
tags: [moc, architecture, flake, nixos, packaging, index]
---

# Flake and System Architecture Map of Content

The structural engineering blueprint of our declarative Nix codebase.

---

## Core Documents

1. [[Nix Flakes - Deep Dive Specification, Anatomy, and Evaluation]]
   - Flake schema specification: `inputs`, `outputs`, URL types, and the `follows` invariant.
   - Standard output attributes: `packages`, `nixosConfigurations`, `devShells`, `overlays`.
   - The `flake.lock` contract: cryptographic `narHash`, evaluation isolation, and reproducible time-travel.

2. [[How to Create a Standalone Flake for Any Software]]
   - Production-tested blueprints for packaging any software archetype natively for NixOS.
   - Blueprint 1: Pre-compiled proprietary binaries (`autoPatchelfHook`, `makeWrapper`).
   - Blueprint 2: Native C/C++ projects (CMake, Meson, Ninja).
   - Blueprint 3: Modern Rust applications (`rustPlatform.buildRustPackage`, `cargoLock`).
   - Blueprint 4: Desktop Electron apps (ASAR unpacking, system Electron wrapping, Wayland injection).
   - Practical techniques for obtaining SRI hashes deterministically.

3. [[Root Flake Topology]]
   - Dependency graph, upstream inputs, and the `follows` invariant.
   - Parameterization of user identity in `user.nix`.
   - Primary `nixosConfigurations.nixos` derivation output.

4. [[Flake Self-Hosting Architecture]]
   - Defending against upstream binary tarball hash mismatches.
   - The pinned fork pattern across `Realdhiru/zen-browser-flake` and `codex-flake`.

5. [[Host Configuration Anatomy]]
   - Intel GPU early KMS in stage-1 initrd, fastboot parameters, and framebuffer compression (`i915.enable_fbc=1`).
   - System-wide native Wayland backend declaration (`NIXOS_OZONE_WL = "1"`).

6. [[Application Packaging - Derivations, FHS, AppImage, and Wrappers]]
   - How to run arbitrary software on NixOS without standard FHS directories.
   - In-depth breakdown of native derivations (`autoPatchelfHook`), FHS environments (`buildFHSEnv`), AppImages (`binfmt_misc`), and runtime wrappers (`makeWrapper` / `symlinkJoin`).

## Related Domains
- [[The Why & Nix Philosophy MOC]]
- [[System Architecture MOC]]
