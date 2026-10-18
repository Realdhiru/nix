---
title: Flake Self-Hosting Architecture
tags: [architecture, flakes, security, stability, hash-drift]
---

# Flake Self-Hosting Architecture: Defending Against Upstream Hash Drift

A critical vulnerability when relying on fast-moving third-party binary applications in NixOS is **upstream tarball hash drift**.

This document explains why we maintain self-hosted flake repositories for critical packages rather than importing public unpinned community flakes.

---

## 1. The Vulnerability: In-Place Upstream Tarball Overwrites

Upstream software maintainers outside the Nix ecosystem frequently release binary packages on GitHub releases (for example, Zen Browser or ChatGPT desktop):
1. Upstream publishes version `v1.23.3b`.
2. A community Nix flake records the SHA-256 hash `sha256-AAAA...` in its package derivation.
3. Upstream discovers a minor packaging oversight (e.g., an incorrect desktop file path inside the tarball) and **re-uploads the tarball directly to the existing GitHub release** without bumping the version number.
4. The next time you run `nixos-rebuild switch`, Nix computes the SHA-256 hash of the downloaded tarball, finds that it evaluates to `sha256-BBBB...`, and aborts the entire system build with:
   ```
   error: hash mismatch in fixed-output derivation:
     specified: sha256-AAAA...
     got:       sha256-BBBB...
   ```
   Because Nix derivations are atomic, this hash mismatch prevents **any** system package update until upstream fixes their repository.

---

## 2. Our Architecture: The Pinned Self-Hosted Flake Pattern

To insulate our operating system from upstream packaging thrashing, we fork and maintain critical binary flakes under the GitHub namespace `Realdhiru`:
- `Realdhiru/zen-browser-flake`
- `Realdhiru/codex-flake`
- `Realdhiru/helium-flake`

### How the Pipeline Operates
1. We control the exact commit pointers and SHA-256 integrity hashes in our personal repositories.
2. When upstream releases an update, an automated updater checks the hash, builds the derivation in an isolated container, and opens a verified PR.
3. Our root system flake points strictly to our personal forks. Upstream tarball changes cannot break an in-progress NixOS rebuild.

## Related Nodes
- [[Root Flake Topology]]
- [[The rebuild() Function]]
- [[Why Flakes Over Legacy Nix Channels]]
