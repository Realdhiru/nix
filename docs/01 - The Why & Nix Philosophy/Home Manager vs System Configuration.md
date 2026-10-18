---
title: Home Manager vs System Configuration
tags: [nix, architecture, home-manager, systemd, privilege-separation]
---

# Home Manager vs System Configuration: Separation of Concerns

A frequent failure mode in NixOS configurations is blurring the line between machine-level operating system configuration and user-space workflow environment.

This document describes the architectural boundary enforced between our NixOS system modules (`hosts/nixos/` and `modules/system/`) and our user environment (`home.nix` and `modules/home/`).

---

## 1. The Separation of Privilege

```
┌─────────────────────────────────────────────────────────────┐
│ System Layer: hosts/nixos/ & modules/system/                │
│ Privileges: root                                            │
│ Scope: Machine hardware, kernel, bootloader, system daemons │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ User Layer: home.nix & modules/home/                        │
│ Privileges: unprivileged user (realdhiru)                   │
│ Scope: Window manager, desktop shell, user daemons, theming │
└─────────────────────────────────────────────────────────────┘
```

### System Configuration Scope
- **Hardware & Firmware**: Intel GPU parameters (`i915`), OLED display quirks, TLP power governor rules, and swapfile hibernation offsets.
- **Security & Privileged Services**: PAM authentication, NetworkManager connectivity, Polkit privilege escalation, and Ly display manager.
- **Global Tooling**: Core CLI utilities needed in emergency maintenance mode (`tree`, `jq`, `socat`, `util-linux`).

### Home Manager Scope
- **Interactive Workflow**: Shell prompt (Zsh + Starship), terminal configuration (Alacritty), and application launcher (Fuzzel).
- **Desktop Shell & Theming**: QuickShell QML widgets, Wallust color extraction templates, and dynamic wallpaper scripts.
- **Supervised User Services**: Background listeners that should restart automatically without root privileges (e.g., `cliphist` clipboard monitors).

---

## 2. Key Advantages of this Boundary

1. **Host Portability**: The entire hardware layer in `hosts/nixos/` can be swapped for a desktop PC or server configuration without touching a single line of your user environment in `home.nix`.
2. **Crash Resilience**: Background user daemons (such as clipboard history listeners) run as systemd user units (`systemd.user.services`). If Hyprland crashes or the user reloads their desktop, systemd automatically restarts user listeners with `Restart = "always"`, preventing orphaned background processes.
3. **No Sudo Requirement for User State**: Managing user tools, audio equalizer presets, and terminal themes requires zero root privileges.

## Related Nodes
- [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]]
- [[Host Configuration Anatomy]]
- [[Root Flake Topology]]
