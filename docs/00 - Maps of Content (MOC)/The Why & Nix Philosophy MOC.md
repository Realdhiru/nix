---
title: The Why & Nix Philosophy Map of Content
type: moc
tags: [moc, philosophy, why-nix, index]
---

# The Why and Nix Philosophy Map of Content

This domain documents the foundational choices that define our system architecture, contrasting declarative engineering against traditional Linux distribution practices.

---

## Core Documents

1. [[Why NixOS Over Arch and Debian]]
   - The failure modes of imperative package managers (state drift, broken upgrades, non-reproducibility).
   - The functional model: system state as an immutable mathematical function.
   - Comparison matrix and practical engineering trade-offs.

2. [[Why Flakes Over Legacy Nix Channels]]
   - Why legacy channels undermine reproducibility via ambient, unversioned state.
   - The lockfile contract (`flake.lock`), pure evaluation, and dependency coordination (`follows`).

3. [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]]
   - Deep dive into the two fundamental ways to declare configs in Nix.
   - Detailed analysis of In-Store Derivations (read-only, pure, slow iteration) vs Out-of-Store Symlinks (`mkOutOfStoreSymlink`, instant live reload).
   - Our hybrid architecture: keeping hardware/packages in-store and user UI live.

4. [[Home Manager vs System Configuration]]
   - Privilege separation: root hardware governance vs unprivileged user workflow.
   - Supervised systemd user daemons vs root daemon sprawl.

## Related Domains
- [[Flake & System Architecture MOC]]
- [[System Architecture MOC]]
