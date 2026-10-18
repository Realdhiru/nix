---
title: External Flakes Used by This System
tags: [nix, flakes, repository]
---

# External Flakes Used by This System

This repository does not maintain a generic standalone-flake packaging tutorial. Reusable packaging guidance is in the `nix-brain` Obsidian vault under [[Packages and Development Environments]].

For this machine, add or change an external flake only when the software cannot be maintained cleanly through the existing NixOS or Home Manager configuration. Record the chosen input, its lockfile effect, package configuration, and rebuild path in the relevant local module documentation.

Current input and package declarations are authoritative in `flake.nix`, `modules/`, and `home.nix`. See [[Root Flake Topology]] and [[Application Packaging - Derivations, FHS, AppImage, and Wrappers]].
