---
title: Why Flakes Over Legacy Nix Channels
tags: [nix, flakes, reproducibility, build-systems, package-management]
---

# Why Flakes Over Legacy Nix Channels

Nix documentation and tutorials frequently reference legacy commands like `nix-channel --add` and `nix-channel --update`. In this configuration, channels are completely decommissioned in favor of **Nix Flakes** (`flake.nix` + `flake.lock`).

This document explains why channels undermine reproducibility and how flakes resolve those shortcomings.

---

## 1. The Architectural Weaknesses of Legacy Nix Channels

### 1. Hidden, Ambient State
Channels rely on unversioned, ambient state stored in the user or root environment (under `~/.nix-defexpr/channels` or `/nix/var/nix/profiles/per-user/root/channels`).
- If two engineers checkout the exact same `configuration.nix` repository on two different machines, but one ran `nix-channel --update` on Monday and the other ran it on Thursday, they will build different package versions.
- Git commits alone cannot guarantee what software was built because the channel pointer is not recorded in the repository.

### 2. Impure Evaluation by Default
Legacy Nix expressions can read environment variables, inspect arbitrary directories on disk, and pull unpinned tarballs (`fetchTarball` without SHA-256 hashes). This violates the foundational promise of pure evaluation.

### 3. Dependency Coordination Friction
When pulling in third-party tooling (such as community window manager modules, browser forks, or custom theming tools), legacy Nix requires manual overrides, custom `NIX_PATH` adjustments, or ad-hoc overlays.

---

## 2. How Flakes Solve the Reproducibility Gap

Nix Flakes introduce three fundamental invariants:

### 1. The Immutable Lockfile (`flake.lock`)
Every external input declared in `flake.nix` is strictly recorded in `flake.lock` with:
- The exact git commit hash of the upstream repository.
- The cryptographic NAR hash (`narHash = "sha256-..."`).
No evaluation can proceed without consulting the lockfile. This guarantees that checking out a commit from six months ago builds the exact same derivations today.

### 2. Pure Evaluation Enforced by the Runtime
Flake builds are pure by default:
- They cannot access filesystem paths outside the git repository.
- They cannot access arbitrary network endpoints during evaluation.
- Uncommitted git changes are ignored unless explicitly staged (`git add`).

### 3. Structured Dependency Sharing (`follows`)
Flakes provide a clean mechanism to deduplicate upstream packages via the `follows` keyword:
```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```
Without `follows`, `home-manager` would evaluate its own copy of Nixpkgs, doubling RAM usage during evaluation and causing package cache misses.

---

## 3. Downsides and Practical Considerations

- **Experimental Feature Flag Required**: Flakes technically remain marked as experimental in Nix upstream. Enabling them requires adding `nix.settings.experimental-features = [ "nix-command" "flakes" ];` in your system configuration.
- **Git Staging Requirement**: If you add a new file to your repository and attempt to rebuild without running `git add`, Nix will report that the file does not exist. (Our custom `rebuild()` function automates staging to eliminate this friction).

## Related Nodes
- [[Why NixOS Over Arch and Debian]]
- [[Root Flake Topology]]
- [[Flake Self-Hosting Architecture]]
