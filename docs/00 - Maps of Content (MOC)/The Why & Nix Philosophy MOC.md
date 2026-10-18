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
   - The tradeoffs and reproducibility limits relevant to this system.

2. [[Why Flakes Over Legacy Nix Channels]]
   - Why this system keeps its Nix inputs in `flake.nix` and `flake.lock`.

3. [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]]
   - Which local configuration areas use Home Manager generations or live links.

4. [[Home Manager vs System Configuration]]
   - Privilege separation: root hardware governance vs unprivileged user workflow.
   - Supervised systemd user daemons vs root daemon sprawl.

## Related Domains
- [[Flake & System Architecture MOC]]
- [[System Architecture MOC]]
