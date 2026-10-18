---
title: Root Flake Topology
tags: [architecture, nix, flakes, dependency-management, overlays]
---

# Root Flake Topology

The primary entry point of the entire operating system configuration is `flake.nix` located at the root of `~/nix`.

This document outlines the dependency tree, input coordination, and output structure defining our NixOS system.

---

## 1. Input Dependency Architecture

Our `flake.nix` coordinates upstream Nixpkgs with curated community modules and self-hosted forks:

```nix
inputs = {
  # Core distribution channel:
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  # User environment manager:
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Self-hosted binary forks (shielded from upstream tarball hash drift):
  zen-browser.url = "github:Realdhiru/zen-browser-flake";
  helium.url = "github:Realdhiru/helium-flake";
  chatgpt.url = "github:Realdhiru/codex-flake";

  # Media theming & extensions:
  spicetify-nix = {
    url = "github:Gerg-L/spicetify-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### The `inputs.nixpkgs.follows` Invariant
In a multi-flake configuration, each community input can declare its own `nixpkgs` dependency. If left unconfigured, Nix will evaluate multiple distinct versions of the Nixpkgs repository tree simultaneously.
- **Ramification**: Massive RAM overhead during evaluation, 10x slower build planning, and binary duplication in the Nix store.
- **Enforcement**: We strictly enforce `inputs.nixpkgs.follows = "nixpkgs"` on all compatible inputs, ensuring the entire system evaluates against a single, unified Nixpkgs closure.

---

## 2. Parameterization and User Identity

To avoid hardcoding usernames (`/home/realdhiru`) throughout nested Nix expressions, user identity is parameterized in `user.nix`:
```nix
{
  username = "realdhiru";
  name = "Dhiru";
  hostname = "nixos";
}
```
The root flake imports `user.nix` once and passes it via `specialArgs` into `nixosSystem` and Home Manager. This guarantees that renaming the user or targeting a new laptop requires editing a single line of code.

---

## 3. Output Derivations

The flake exposes one primary system derivation:
- `nixosConfigurations.nixos`: Evaluated for `x86_64-linux` and invoked via `nixos-rebuild switch --flake ~/nix#nixos`.
- **System Top-Level Closure**: Assembles the kernel, stage-1 initrd, systemd units, system-level packages, and embeds the Home Manager generation.

## Related Nodes
- [[Flake Self-Hosting Architecture]]
- [[Host Configuration Anatomy]]
- [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]]
