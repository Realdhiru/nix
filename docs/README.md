# NixOS Rice — Documentation Home

High-level architecture map and system layout.

---

## System at a Glance

- **Host:** ASUS Vivobook S15 OLED (K5504VA), Intel Core i9-13900H, Iris Xe Graphics, x86_64
- **OS:** NixOS Unstable, Flakes, Home Manager
- **Compositor:** Hyprland (Lua configuration)
- **Desktop Shell:** QuickShell (Native event-driven QML widgets)
- **Theming:** Dynamic Material You (Matugen wallpaper palette generation)
- **Power Authority:** TLP 1.9.1 (`power.nix`), ASUS daemon strictly for 80% charge ceiling

## Repository Layout

```text
~/nix/
├── flake.nix                  # Flake inputs, overlays, HM wiring, qml-lint check
├── user.nix                   # Single source of truth (username, name, hostname)
├── hosts/nixos/
│   ├── default.nix            # Host configuration & module imports
│   ├── hardware-configuration.nix
│   └── hardware/              # Machine-specific quirks (asus.nix, sonix-webcam.nix)
├── modules/
│   ├── system/                # boot, services, packages, power, fonts, gaming, users
│   └── home/                  # shell, theme, spicetify
├── home.nix                   # Dotfile symlinks, systemd user services, EasyEffects
├── pkgs/                      # Custom derivations (buuf-nestort, hypr-kdeconnect, pcmanfm patch)
├── dotfiles/                  # Out-of-store live configurations
│   ├── hypr/                  # Lua Hyprland configs, scripts/, quickshell/
│   ├── fuzzel/ wezterm/ fastfetch/ matugen/ opencode/
└── docs/                      # Architectural docs (decisions.md, flow.md, installation.md)
```

## Documentation Index

- **[`decisions.md`](file:///home/realdhiru/nix/docs/decisions.md)**: Architectural invariants, hardware decisions, and system non-negotiables.
- **[`debugging.md`](file:///home/realdhiru/nix/docs/debugging.md)**: Historical issues, root causes, and verified technical solutions.
- **[`flow.md`](file:///home/realdhiru/nix/docs/flow.md)**: Boot sequence, startup ordering, QuickShell lifecycle, and emergency recovery.
- **[`installation.md`](file:///home/realdhiru/nix/docs/installation.md)**: Fresh machine deployment guide.
- **[`CHANGELOG.md`](file:///home/realdhiru/nix/CHANGELOG.md)**: Chronological daily log of changes and fixes.
