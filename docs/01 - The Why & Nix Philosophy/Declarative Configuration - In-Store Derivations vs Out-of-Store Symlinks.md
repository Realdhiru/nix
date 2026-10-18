---
title: Configuration File Ownership in This System
tags: [home-manager, dotfiles, repository-decision]
---

# Configuration File Ownership in This System

This page records which parts of this repository are live-linked and which are managed through Nix generations. It is not a general Home Manager tutorial.

| Area | Ownership here | Reason |
| --- | --- | --- |
| QuickShell, Hyprland Lua, Wallust templates | Live links into `~/nix/dotfiles` | Direct edit and reload loop for desktop configuration. |
| Host hardware, system services, package declarations | NixOS configuration | Changes are evaluated and activated as system generations. |
| Static Home Manager files | Home Manager generation | Managed with the user configuration and its activation. |

The source of truth for the current links is `home.nix`. Confirm the exact mapping there before changing this table. Live-linked edits are mutable working-tree state and are not restored by a NixOS generation rollback. See [[The Out-of-Store Symlink Paradigm]] and [[Home Manager vs System Configuration]].

General Nix store, generation, and module concepts are covered in the separate `nix-brain` vault: [[Nix Mental Model]] and [[NixOS Modules and System Configuration]].
