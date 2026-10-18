---
title: Flake Evaluation and Outputs in This Repository
tags: [nix, flakes, repository]
---

# Flake Evaluation and Outputs in This Repository

This page records how the local system consumes its flake. General flake syntax and concepts belong in the separate `nix-brain` Obsidian vault.

## Local entry points

- `flake.nix` declares the pinned inputs and exports the host configuration.
- `flake.lock` records the resolved input revisions used by evaluation.
- `nixosConfigurations.<host>` is the system rebuild target.
- `nixpkgs`, Home Manager, and other inputs are coordinated in `flake.nix`; inspect the file for the current `follows` relationships.
- `nixos-rebuild` is invoked through the repository's rebuild workflow; see [[Root Flake Topology]] and [[Flake Self-Hosting Architecture]].

## Operational notes

- Review `git status` before rebuilding. Flake source visibility depends on the repository state and tracked files; do not assume an untracked file is available to evaluation.
- Update inputs deliberately, inspect the resulting `flake.lock` diff, then rebuild through the documented workflow.
- A lockfile pins source inputs; it does not pin hardware, mutable user data, external services, or every runtime condition.
- For language and flake fundamentals, see the `nix-brain` vault's [[Flakes and Inputs]] and [[Nix Mental Model]].

## Related local pages

- [[Root Flake Topology]]
- [[Flake Self-Hosting Architecture]]
- [[Host Configuration Anatomy]]
- [[Why Flakes Over Legacy Nix Channels]]
