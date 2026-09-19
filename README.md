# ❄️ Declarative NixOS & Hyprland Rice

<div align="center">

[![NixOS](https://img.shields.io/badge/NixOS-Unstable-blue?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00B4D8?style=for-the-badge&logo=hyprland&logoColor=white)](https://hyprland.org)
[![QuickShell](https://img.shields.io/badge/UI-QuickShell_(QML)-8338EC?style=for-the-badge)](https://git.outfoxxed.me/outfoxxed/quickshell)
[![Theming](https://img.shields.io/badge/Theme-Matugen-FF006E?style=for-the-badge)](https://github.com/InioX/matugen)
[![Flakes](https://img.shields.io/badge/Config-Nix_Flakes-52B788?style=for-the-badge&logo=nixos)](https://wiki.nixos.org/wiki/Flakes)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

<p align="center">
  A declarative, reproducible personal desktop environment configured with Nix Flakes, Hyprland, and QuickShell.
</p>

</div>

---

## Showcase

<div align="center">

### Desktop Tour

<video src="https://github.com/user-attachments/assets/15bb75f7-ee3c-4942-99e7-63ec23de43ce" controls autoplay width="900"></video>

<br/>

<sub>Wallpapers used in this setup are available in [Realdhiru/wallps](https://github.com/Realdhiru/wallps). Base desktop widgets were adapted from [ilyamiro/serpantinum](https://github.com/ilyamiro/serpantinum).</sub>

</div>

### 🌟 QuickShell Desktop Widgets & Features

Custom event-driven QML widgets built natively on [QuickShell](https://git.outfoxxed.me/outfoxxed/quickshell) with zero polling overhead, Wayland IPC integration, and fluid micro-animations:

<table>
  <tr>
    <td width="50%" align="center">
      <b>Wallpaper Picker & Downloader</b><br/>
      <img src="docs/assets/wallpaper_carousel.webp" alt="Wallpaper Picker" width="100%" /><br/>
      <sub>3D parallax carousel with wallpaper browsing, online search & download, and instant switching.</sub>
    </td>
    <td width="50%" align="center">
      <b>Network Manager</b><br/>
      <img src="docs/assets/radial_connectivity.webp" alt="Network Manager" width="100%" /><br/>
      <sub>Radial interface for Wi-Fi, Ethernet, Bluetooth, and hotspot management.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <b>Media Player & Equalizer</b><br/>
      <img src="docs/assets/media_equalizer.webp" alt="Media Player & Equalizer" width="100%" /><br/>
      <sub>Vinyl playback animation, MPRIS controls, and 10-band EasyEffects equalizer.</sub>
    </td>
    <td width="50%" align="center">
      <b>Monitor Control</b><br/>
      <img src="docs/assets/display_manager.webp" alt="Monitor Control" width="100%" /><br/>
      <sub>Resolution, scaling, rotation, and refresh rate controls.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <b>Calendar & Weather</b><br/>
      <img src="docs/assets/calendar_weather.webp" alt="Calendar & Weather" width="100%" /><br/>
      <sub>TopBar clock expansion with weather, forecast, calendar, and fastfetch.</sub>
    </td>
    <td width="50%" align="center">
      <b>Screen Time</b><br/>
      <img src="docs/assets/focus_timer.webp" alt="Screen Time" width="100%" /><br/>
      <sub>Per-app usage tracking, daily screen time charts, and focus timer.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <b>Clipboard Manager</b><br/>
      <img src="docs/assets/clipboard_manager.webp" alt="Clipboard Manager" width="100%" /><br/>
      <sub>Clipboard history with image previews, text snippets, and search.</sub>
    </td>
    <td width="50%" align="center">
      <b>App Launcher</b><br/>
      <img src="docs/assets/app_launcher.webp" alt="App Launcher" width="100%" /><br/>
      <sub>Fuzzel launcher with fuzzy matching and custom icon theme.</sub>
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center">
      <b>Instant File Search</b><br/>
      <img src="docs/assets/file_search.webp" alt="File Search" width="60%" /><br/>
      <sub>Fuzzel-powered file search with directory navigation.</sub>
    </td>
  </tr>
</table>

---

## 🛠️ Software Stack & Rice Components

| Component | Software | Description |
| :--- | :--- | :--- |
| **OS & Package Manager** | [NixOS](https://nixos.org) (Unstable) + [Nix Flakes](https://wiki.nixos.org/wiki/Flakes) | Declarative, reproducible system with atomic generations |
| **Compositor / WM** | [Hyprland](https://hyprland.org) | Wayland dynamic tiling compositor configured in native Lua |
| **Desktop Shell & UI** | [QuickShell](https://git.outfoxxed.me/outfoxxed/quickshell) (Qt6 / QML) | Event-driven topbar, circular battery dial, MPRIS music & power popups |
| **Application Launcher** | [Fuzzel](https://codeberg.org/dnkl/fuzzel) | Wayland dmenu/rofi alternative with custom frosted glass styling |
| **Shell & Prompt** | [Zsh](https://www.zsh.org/) + [Starship](https://starship.rs/) | Fast, modular shell prompt with automated safety-gated `rebuild()` |
| **Theming** | [Matugen](https://github.com/InioX/matugen) (Material You) | Wallpaper-derived dynamic color extraction across GTK, Qt, WezTerm, QuickShell, and Cava |
| **Icon Theme** | Buuf-Nestort | Hand-drawn skeuomorphic icon theme |
| **Typography** | JetBrains Mono Nerd Font | Monospace code font with comprehensive glyph and symbol support |
| **Lockscreen & Idle** | [Hyprlock](https://github.com/hyprwm/hyprlock) + [Hypridle](https://github.com/hyprwm/hypridle) | Wayland lockscreen with live video background support (QtMultimedia) |
| **Wallpaper Daemons** | [awww](https://github.com/AvengeMedia/awww) + [mpvpaper](https://github.com/GhostNaN/mpvpaper) | High-performance static and live video wallpaper renderers |
| **Media Player** | [MPV](https://mpv.io) (with `mpvScripts.mpris`) | Hardware-accelerated player broadcasting D-Bus media tracking |
| **Music Streaming** | Spotify + [Spicetify](https://spicetify.app/) | Customized Spotify with Marketplace themes & extensions |
| **Screen Recording** | [GPU Screen Recorder](https://git.dec05eba.com/gpu-screen-recorder-gtk/) | Low-overhead NVENC/VAAPI screen capture |
| **Screenshots & Snips** | Grim + Slurp + Grimblast | Wayland screenshot suite with region selection & clipboard copy |
| **Audio Server & FX** | [PipeWire](https://pipewire.org) + WirePlumber + [EasyEffects](https://github.com/wwmm/easyeffects) | Low-latency audio routing, DSP plugins & mic noise cancellation |
| **Power Management** | [TLP](https://linrunner.de/tlp/) + [asusctl](https://asus-linux.org/) (`asusd`) | Hardware power profiles + 80% battery charge ceiling authority |
| **File Management** | [PCManFM-Qt](https://github.com/lxqt/pcmanfm-qt) + Filelight | Lightweight Qt file manager & interactive disk usage map |

---

## Installation & Deployment

This configuration is built for **100% portability** (similar to the Omarchy distribution standard). You can fork and deploy it on any machine with zero hardcoded paths:
- Complete guide: [`docs/installation.md`](file:///home/realdhiru/nix/docs/installation.md)
- User identity is configured entirely in a single file: [`user.nix`](file:///home/realdhiru/nix/user.nix)

---

## Design & Technical Highlights

### Power & Thermal Management
- **Hardware-Level Power Authority**: TLP coordinates CPU energy-performance preferences (EPP), ASPM, and platform profiles, while enforcing an 80% battery charge ceiling (`charge_control_end_threshold = 80`) directly at the firmware level to preserve cell health.
- **Dynamic GPU Shader Bypass**: On battery-saver profiles or solid black wallpapers, compositor dual-kawase blur shaders and drop shadows are automatically bypassed with 100% opaque window rendering, eliminating multi-pass GPU alpha-blending.
- **Event-Driven Telemetry (Zero Polling Loops)**: System telemetry reads directly from Linux kernel uevents and sysfs watchers rather than periodic shell polling timers. In-process `/proc` inspection in background daemons eliminates unnecessary subprocess forks, allowing CPU package states to settle into deep C-state sleep.
- **Transient Spike Control**: Disables aggressive dynamic frequency boost on battery to eliminate thermal spikes from background Chromium and Electron processes.

### Compositor & Desktop Workflow
- **Modular Lua Configuration**: Hyprland configuration is organized cleanly in native Lua modules (`hyprland.lua`), decoupling keybinds, rules, window animations, and environment variables.
- **Frame-0 Hot Reloading**: Synchronously evaluates cached power and visual states at startup and reload (`SUPER + R`), applying compositor rules in ~15ms without unmapping Wayland surfaces or cold-restarting desktop shell widgets.
- **Low-Latency Compositing Mode**: A dedicated keybind (`SUPER + SHIFT + G`) toggles Direct Scanout (`render:direct_scanout = 2`), Adaptive Sync (VRR), and asynchronous tearing for latency-sensitive full-screen workloads.
- **Pure Wayland Pipeline**: All Chromium and Electron apps run with native Wayland flags (`NIXOS_OZONE_WL = "1"`), providing kinetic touchpad gestures and subpixel scrolling.
- **Fuzzy File Navigation & Theming**: Centered interactive file search (`SUPER + SPACE`) with instant parent directory navigation in `pcmanfm-qt`, paired with in-place Matugen palette syncing across widgets, terminal, and launcher.

### Declarative System Infrastructure
- **Safety-Gated Rebuild Workflow**: A custom rebuild pipeline validates builds before activation, runs a post-switch health gate with automated rollbacks, and retains a 14-day garbage collection safety window while tracking floating `nixos-unstable`.
- **Integrated System Packaging**: Declarative custom derivations (including `hypr-kdeconnect-portal` for remote input over `/dev/uinput`), native AppImage execution via Linux kernel `binfmt_misc`, and declarative Flathub integration.
- **Clean Display Authentication**: Lightweight TTY display manager (`ly`) with PAM authentication, cleanly decoupling graphical login from session startup.

---

## Architecture & System Structure

```text
nix/
├── flake.nix                          # Flake entrypoint, nixpkgs-unstable & community inputs
├── flake.lock                         # Deterministic input lockfile
├── home.nix                           # Home Manager root configuration
├── pkgs/                              # Custom Nix package derivations & patches
│   ├── buuf-nestort.nix
│   ├── hypr-kdeconnect-portal.nix
│   └── pcmanfm-qt-appid.patch
├── hosts/
│   └── nixos/
│       ├── default.nix                # Host-level imports, disk UUIDs & swap configuration
│       ├── hardware-configuration.nix # Kernel modules, filesystems, and hardware drivers
│       └── hardware/                  # Machine-specific hardware quirks
│           ├── asus.nix               # ASUS ROG/TUF asusd & brightness hotkey handling
│           └── sonix-webcam.nix       # Sonix USB webcam V4L2 loopback pipeline
├── modules/
│   ├── system/                        # Portable declarative NixOS system services
│   │   ├── boot.nix                   # systemd-boot EFI, kernel tuning & ZRAM
│   │   ├── fonts.nix                  # CJK, monospace, and Nerd Font typography
│   │   ├── gaming.nix                 # Low-latency gaming kernel & graphics stack
│   │   ├── packages.nix               # System-wide CLI & GUI package manifests
│   │   ├── power.nix                  # TLP power management & battery charge thresholds
│   │   ├── services.nix               # NetworkManager, PipeWire, udev, & D-Bus daemons
│   │   └── users.nix                  # User account privileges & sudo rules
│   └── home/                          # User-space Home Manager modules
│       ├── shell.nix                  # Zsh environment, custom rebuild() gate & aliases
│       ├── spicetify.nix              # Declarative Spotify theming
│       └── theme.nix                  # GTK, icon, and cursor theming
├── dotfiles/                          # Symlinked user configuration tree
│   ├── fastfetch.jsonc                # System info presenter
│   ├── starship.toml                  # Minimal shell prompt
│   ├── wezterm.lua                    # Hardware-accelerated GPU terminal
│   ├── fuzzel/
│   │   └── fuzzel.ini                 # 2x HiDPI centered application & file launcher
│   ├── matugen/                       # Dynamic color extraction config & templates
│   └── hypr/                          # Hyprland Wayland compositor configuration (Lua)
│       ├── hyprland.lua               # Compositor core entrypoint
│       ├── appearance.lua             # Dual-kawase blur, shadows, and smooth Bezier curves
│       ├── keybinds.lua               # Window management, workspace & utility keybindings
│       ├── rules.lua                  # Window rules & Frame-0 opacity evaluation
│       ├── scripts/                   # Performance toggles & helper utilities
│       └── scripts/quickshell/        # Curated QuickShell QML widget suite
│           ├── Shell.qml              # Wayland layer-shell root entrypoint
│           ├── TopBar.qml             # Status bar (Kanji workspaces, clock, tray, battery)
│           ├── SysData.qml            # Hardware telemetry & live profile listener
│           ├── battery/               # Control center popup (power, brightness, audio, actions)
│           ├── network/               # Wi-Fi network panel & hotspot controller
│           ├── music/                 # MPRIS media player drawer
│           └── watchers/              # Event-driven udev and PipeWire stream watchers
└── docs/
    ├── decisions.md                   # Chronological architectural & engineering rationale
    ├── flow.md                        # Emergency recovery & runtime flows
    └── assets/                        # High-resolution showcase media
```

---

## Setup & Reproduction

### 1. Prerequisites (Fresh Machine)
Ensure NixOS is installed and Flakes are enabled in `/etc/nixos/configuration.nix`:
```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

### 2. Clone & Adapt Hardware
```bash
git clone https://github.com/Realdhiru/nix.git ~/nix
cd ~/nix

# Generate hardware configuration for the target machine
nixos-generate-config --show-hardware-config > hosts/nixos/hardware-configuration.nix
```

### 3. Initial Build & Activation
```bash
# Build and activate the configuration
sudo nixos-rebuild switch --flake .#nixos
```

### 4. Custom Management Commands

The shell environment (`modules/home/shell.nix`) provides a dedicated suite of workflow functions to manage, inspect, and maintain the system safely:

#### `rebuild [commit message]`
The primary command for applying configuration changes. It implements an automated health-gated safety pipeline:
1. Records the previous known-good system generation and git revision to `~/.cache/nix_rebuild_log`.
2. Creates an atomic `known-good` git tag and automatically stages/commits all modified files.
3. Executes `sudo nixos-rebuild build --flake .#nixos`. If compilation fails, execution aborts immediately without activating anything.
4. Switches to the new generation and executes `scripts/health-check.sh` (validating Hyprland session integrity and GPU-hang probes).
5. If a critical failure is detected, it **automatically rolls back** to the previous generation, preserves the failed generation in the bootloader for debugging, and generates a diagnostic log.

```bash
# Example: Apply changes with an automated commit & health check
rebuild "feat: adjust hyprland window rules"
```

#### `update`
Pulls the latest git changes, updates flake inputs to the latest `nixos-unstable` revision, and executes a verified rebuild:
```bash
update
```

#### `gens`
Displays an annotated, color-coded list of all system generations present in `/nix/var/nix/profiles/`, highlighting the currently `[ACTIVE]` generation and any `[PINNED STABLE]` generations:
```bash
gens
```

#### `pin-stable [generation_number]`
Pins a specific generation (or the currently active generation if no argument is passed) as a permanent GC root (`/nix/var/nix/gcroots/boot-stable`). Pinned generations are permanently protected from garbage collection:
```bash
# Pin current generation
pin-stable

# Pin specific generation (e.g. generation 835)
pin-stable 835
```

#### `clean`
Safely purges unpinned Nix store paths older than 14 days (`--delete-older-than 14d`), ensuring that rollback targets and recent known-good generations remain fully bootable:
```bash
clean
```

#### `ff` & `af`
- **`ff`**: Quick alias for `fastfetch`.
- **`af`**: Interactive animated terminal fetcher that cycles through GIFs/MP4s in `~/Pictures/fastfetch` using `anifetch`, dynamically calculating terminal cell aspect ratios (`ffprobe`) to prevent image distortion.