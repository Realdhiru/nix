# Installation & Deployment Guide

This repository contains a declarative NixOS workstation configuration featuring Hyprland, QuickShell, dynamic Wallust color palette generation, and TLP hardware power management.

Shared desktop behavior is separated from machine facts and personal preferences. The current flake targets x86_64-linux; hardware support is selected through each host's generated facts and hardware configuration.

---

## 1. Quick Start (Fresh Machine)

### Step 1: Clone the Repository
Clone this repository to `~/nix`:
```bash
git clone https://github.com/<your-username>/nix.git ~/nix
cd ~/nix
```

### Step 2: Generate Host Configuration
Choose a short host name and run the generator from the repository root. It writes the host's system facts and a fresh hardware configuration, and refuses to overwrite existing files:
```bash
nix run .#init-host -- <host-name>
git add hosts/<host-name>/hardware-configuration.nix hosts/<host-name>/system.nix
```
Review the generated host files. Set identity, home path, locale, keyboard, application defaults, theme, and personal power/audio preferences in [`user.nix`](../user.nix). Shared implementation belongs in `modules/` and `dotfiles/`.

### Step 3: Build and Activate
For the first installation, build and switch explicitly without staging unrelated files:
```bash
sudo nixos-rebuild switch --flake ~/nix#<host-name>
```

For later changes, use the `rebuild` shell function. It runs `nix flake check`, builds and switches the current working tree, then runs the repository health check and rolls back on critical failures. It never stages or commits by default. `rebuild -c [message]` commits only already-staged files after a healthy switch, ignores unrelated unstaged work, and stops when a staged path has additional unstaged edits.

Once the switch completes, reboot your machine:
```bash
systemctl reboot
```

---

## 2. System Architecture & CLI Multi-Tools

All desktop scripts follow a **domain multi-tool pattern** rather than scattered single-use scripts:

### Wallpaper System (`dotfiles/wallpaper/wallpaper.sh`)
Unified CLI managing all wallpaper lifecycle events:
```bash
~/.config/wallpaper/wallpaper.sh set <path>      # Set image, GIF, or video wallpaper
~/.config/wallpaper/wallpaper.sh boot            # Initialize wallpaper at session start
~/.config/wallpaper/wallpaper.sh kill            # Toggle wallpaper-kill mode
~/.config/wallpaper/wallpaper.sh ensure          # Ensure the wallpaper backend is ready
~/.config/wallpaper/wallpaper.sh thumb           # Generate picker previews and links
~/.config/wallpaper/wallpaper.sh watch           # Watch the configured wallpaper directory
~/.config/wallpaper/wallpaper.sh clean           # Remove orphaned cache entries and links
```

### Power & Session System (`dotfiles/hypr/scripts/power.sh`)
Unified CLI for session locking, sleep, lid switch, idle inhibition, and power profiles:
```bash
power.sh lock                # Fast GPU lockscreen via Hyprlock (ext-session-lock-v1) with single-flight mutex
power.sh profile <profile>   # Switch hardware profile: performance, balanced, or power-saver
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
  "workspaceCount": 8
}
```

Monitor modes and layout are discovered from the live outputs and stored in `${XDG_STATE_HOME:-$HOME/.local/state}/desktop/monitors/intent.json`; do not add a connector or resolution list to `settings.json`.

- **`PopupCard.qml`**: Standardized base container for all QuickShell popups, enforcing uniform borders, opacity, corner radii, and frosted specular highlights.
- **Wallust**: Colors automatically derive from the active wallpaper and propagate to QuickShell, Foot, Alacritty, GTK 3/4, and Qt apps in real time.
