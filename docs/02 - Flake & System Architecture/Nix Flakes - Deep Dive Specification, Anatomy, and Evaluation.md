---
title: Nix Flakes - Deep Dive Specification, Anatomy, and Evaluation
tags: [nix, flakes, architecture, evaluation, lockfiles, outputs, schema]
---

# Nix Flakes: Deep Dive Specification, Anatomy, and Evaluation

Nix Flakes represent the modern evolution of the Nix language and packaging system. Introduced by Eelco Dolstra in RFC 0049, flakes transform Nix from an ad-hoc, ambiently evaluated functional language into a hermetic, composable, and standardized software unit.

This document details the exact schema, evaluation lifecycle, lockfile mechanics, and input resolution rules governing Nix Flakes.

---

## 1. Anatomy of a Flake (`flake.nix`)

A flake is simply any filesystem directory or Git repository containing a `flake.nix` file at its root. Unlike legacy Nix expressions, `flake.nix` enforces a standardized attribute set structure with two mandatory top-level attributes:

```nix
{
  description = "A concise, human-readable summary of the flake's purpose";

  inputs = {
    # External dependencies required to evaluate this flake
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    # Derivations, configurations, shells, and modules emitted by this flake
  };
}
```

---

## 2. The Input Specification (`inputs`)

The `inputs` attribute set defines all external source trees needed during evaluation.

### Types of Input URIs
Flakes support multiple URL protocols:
- **GitHub / GitLab / SourceHut**: `github:owner/repo/branch-or-tag` (e.g. `github:nixos/nixpkgs/nixos-unstable`).
- **Raw Git Repositories**: `git+https://example.com/repo.git?ref=main`.
- **Tarballs**: `tarball+https://example.com/archive.tar.gz`.
- **Local Filesystem Directories**: `path:/home/user/projects/my-flake` or `./sub-flake`.

### Input Overrides: The `follows` Keyword
By default, each declared input evaluates its own internal inputs recursively. If `flake-a` depends on `nixpkgs` revision X, and `flake-b` depends on `nixpkgs` revision Y, Nix evaluates **both** complete trees.

To force dependency deduplication:
```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs"; # Overrides home-manager's nixpkgs with ours
  };
};
```
- **Evaluation Impact**: Cuts Nix memory usage in half during evaluation.
- **Cache Impact**: Guarantees that packages compiled by `home-manager` share the exact same glibc, OpenSSL, and Python runtimes as the system configuration, avoiding duplicate compiles.

---

## 3. The Standardized Output Schema (`outputs`)

Unlike legacy Nix expressions which could return arbitrary data types, Flakes define a standardized naming convention for output attributes. When external tools or the Nix CLI interact with your flake, they query these standard paths:

### System & Host Configurations
- `nixosConfigurations.<hostname>`: Evaluated via `nixpkgs.lib.nixosSystem`. Invoked via:
  ```bash
  nixos-rebuild switch --flake .#<hostname>
  ```
- `homeConfigurations.<username>`: Evaluated via `home-manager.lib.homeManagerConfiguration`.

### Packages and Derivations
- `packages.<system>.<packageName>`: The default target for `nix build .#<packageName>`.
- `packages.<system>.default`: The target invoked when running bare `nix build`.

### Developer Environments
- `devShells.<system>.<shellName>`: Target for `nix develop .#<shellName>`.
- `devShells.<system>.default`: Target invoked when running bare `nix develop`.

### Modules and Overlays
- `nixosModules.<name>`: Reusable NixOS system modules exported for downstream flakes.
- `overlays.<name>`: Package overrides injected into downstream `pkgs` evaluations.
- `checks.<system>.<checkName>`: Automated test derivations evaluated via `nix flake check`.

---

## 4. The Lockfile (`flake.lock`): The Purity Contract

Whenever Nix evaluates a flake, it consults `flake.lock`. If `flake.lock` does not exist, Nix resolves every input URL to its latest upstream commit and writes the lockfile.

### Anatomy of a Lock Entry:
```json
"nixpkgs": {
  "locked": {
    "lastModified": 1729188000,
    "narHash": "sha256-5wt81jeH5/eYqE/sRT9cRGuRh3vT9hLo+5jpt2zIESA=",
    "owner": "nixos",
    "repo": "nixpkgs",
    "rev": "55bfb4d8a1c8b7...",
    "type": "github"
  },
  "original": {
    "owner": "nixos",
    "ref": "nixos-unstable",
    "repo": "nixpkgs",
    "type": "github"
  }
}
```

### The Three Invariants of the Lockfile:
1. **Cryptographic Immutability**: The `narHash` verifies the SHA-256 integrity of the unpacked Nix Archive (NAR). If upstream rewrites Git history or modifies a branch pointer, Nix aborts with an integrity mismatch.
2. **Deterministic Time-Travel**: Checking out a Git commit from 2 years ago containing a `flake.lock` reconstructs the exact build graph from that date.
3. **No Network Round-Trips on Build**: If the store already contains paths matching the locked `narHash`, Nix never contacts GitHub or the network during evaluation.

## Related Nodes
- [[How to Create a Standalone Flake for Any Software]]
- [[Root Flake Topology]]
- [[Flake Self-Hosting Architecture]]
- [[Why Flakes Over Legacy Nix Channels]]
