# Installation & Deployment Guide

This repository contains a declarative, production-ready NixOS workstation configuration featuring Hyprland, QuickShell, dynamic Matugen color palette generation, and TLP hardware power management.

It is engineered with a **portable, single-source user architecture** (similar to the Omarchy distribution model), meaning you can fork, clone, and deploy it on any machine without having to hunt down hardcoded paths or usernames.

---

## 1. Quick Start (Fresh Machine)

### Step 1: Clone the Repository
Clone this repository to `~/nix`:
```bash
git clone https://github.com/<your-username>/nix.git ~/nix
cd ~/nix
```

### Step 2: Configure Your Identity (`user.nix`)
Open [`user.nix`](file:///home/realdhiru/nix/user.nix) in your editor:
```nix
{
  username = "yourusername";      # Your Linux account username
  name     = "Your Full Name";    # Display name
  email    = "you@example.com";   # Git / contact email
  hostname = "yourhostname";      # System hostname
}
```
> [!NOTE]
> This single file configures your NixOS user account, passwordless sudo permissions, Home Manager profile, and systemd user services. You do not need to edit any other Nix files for user configuration.

### Step 3: Generate Hardware Configuration
Generate the hardware specification for your physical machine and save it to the host configuration:
```bash
nixos-generate-config --show-hardware-config > ~/nix/hosts/nixos/hardware.nix
```

### Step 4: Build and Activate
Ensure all files are tracked by Git, then build and switch:
```bash
git add -A
sudo nixos-rebuild switch --flake .#nixos
```

Once the switch completes, reboot your machine:
```bash
systemctl reboot
```

---

## 2. System Architecture & CLI Multi-Tools

All desktop scripts follow a **domain multi-tool pattern** rather than scattered single-use scripts:

### Wallpaper System (`dotfiles/hypr/scripts/wallpaper.sh`)
Unified CLI managing all wallpaper lifecycle events:
```bash
wallpaper.sh set <path>      # Set active image, GIF, or MP4 video wallpaper
wallpaper.sh boot            # Cold-boot wallpaper loader
wallpaper.sh kill            # Teardown wallpaper daemons and reset theme to neutral
wallpaper.sh ensure          # Safe, idempotent awww-daemon lifecycle manager
wallpaper.sh thumb           # Generate previews and flat links for QuickShell picker
wallpaper.sh watch           # Background inotify watcher for ~/Pictures/Wallpapers
wallpaper.sh clean           # Purge orphaned cache entries and broken symlinks
```

### Power & Session System (`dotfiles/hypr/scripts/power.sh`)
Unified CLI for session locking, sleep, lid switch, and idle inhibition:
```bash
power.sh lock                # Safe QuickShell Lock.qml launcher (ext-session-lock-v1)
power.sh suspend             # Suspend system with automated pre-lock
power.sh resume              # Post-hardware-wake state restoration
power.sh lid close|open      # Laptop lid switch event handler
power.sh inhibit             # Toggle idle inhibition (Coffee mode)
```

### QuickShell Manager (`dotfiles/hypr/scripts/qs_manager.sh`)
Unified widget toggler and state manager:
```bash
qs_manager.sh toggle music
qs_manager.sh toggle battery
qs_manager.sh toggle network
qs_manager.sh toggle clipboard
qs_manager.sh toggle monitors
qs_manager.sh toggle calendar
qs_manager.sh toggle focustime
qs_manager.sh toggle wallpaper
```

### Unified Launcher (`dotfiles/hypr/scripts/fuzzel_menu.sh`)
Interactive application menu and file search:
```bash
fuzzel_menu.sh app           # Application launcher
fuzzel_menu.sh file          # Fast visual file and document finder
```

---

## 3. UI & Appearance Customization

You can customize the desktop shell without modifying QML code by editing [`dotfiles/hypr/settings.json`](file:///home/realdhiru/nix/dotfiles/hypr/settings.json):
```json
{
  "uiScale": 1.0,
  "popupOpacity": 0.2,
  "cardOpacity": 0.0,
  "borderWidth": 0,
  "wallpaperDir": "~/Pictures/Wallpapers",
  "workspaceCount": 8,
  "monitors": [
    {
      "name": "eDP-1",
      "resW": 2880,
      "resH": 1620,
      "rate": 120,
      "scale": 2
    }
  ]
}
```

- **`PopupCard.qml`**: Standardized base container for all QuickShell popups, enforcing uniform borders, opacity, corner radii, and frosted specular highlights.
- **Matugen**: Colors automatically derive from the active wallpaper and propagate to QuickShell, WezTerm, GTK 3/4, and Qt apps in real time.
