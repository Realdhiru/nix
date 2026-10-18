---
title: Live Dotfile Links in This System
tags: [home-manager, dotfiles, repository]
---

# Live Dotfile Links in This System

This repository links selected desktop configuration directories directly from `~/nix/dotfiles` so edits are immediately visible to the running desktop. The authoritative link declarations are in `home.nix`.

The linked files are mutable working-tree state. A NixOS generation rollback does not restore edits made in those files; use Git history or discard the local edits deliberately. System and hardware configuration remain managed through the declared NixOS configuration.

Use the documented reload command after changes, and follow the widget-specific guidance before QuickShell reloads. See [[Configuration File Ownership in This System]], [[QuickShell Event-Driven IPC]], and [[Lua Configuration Model]].

General differences between store-managed files and live symlinks are in the `nix-brain` vault's [[NixOS Modules and System Configuration]].
