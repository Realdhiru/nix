# ❄️ Declarative NixOS & Hyprland Rice

<div align="center">

[![NixOS](https://img.shields.io/badge/NixOS-Unstable-blue?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00B4D8?style=for-the-badge&logo=hyprland&logoColor=white)](https://hyprland.org)
[![QuickShell](https://img.shields.io/badge/UI-QuickShell_(QML)-8338EC?style=for-the-badge)](https://git.outfoxxed.me/outfoxxed/quickshell)
[![Theming](https://img.shields.io/badge/Theme-Matugen-FF006E?style=for-the-badge)](https://github.com/InioX/matugen)
[![Flakes](https://img.shields.io/badge/Config-Nix_Flakes-52B788?style=for-the-badge&logo=nixos)](https://wiki.nixos.org/wiki/Flakes)

<p align="center">
  <b>A fully declarative, mathematically reproducible desktop engineered for sub-millisecond IPC responsiveness, hardware-enforced battery efficiency, and zero-flicker HiDPI Wayland compositing.</b>
</p>

</div>

---

## Showcase

<div align="center">

### Desktop & Interface
<img src="docs/assets/hero_desktop.png" alt="Desktop Overview" width="850" />

<br/>

| Control Center | Network Panel |
| :---: | :---: |
| <img src="docs/assets/battery_control_center.png" alt="Control Center" width="410" /> | <img src="docs/assets/wifi_network_panel.png" alt="Network Panel" width="410" /> |

| Fuzzel Launcher | Fast File Search |
| :---: | :---: |
| <img src="docs/assets/fuzzel_launcher.png" alt="Fuzzel Launcher" width="410" /> | <img src="docs/assets/fuzzel_file_search.png" alt="Fuzzel File Search" width="410" /> |

</div>

---

## Why This Over Automated Install Scripts / Generic Dotfiles?

Most popular rice repositories and automated install scripts (e.g. Hyprdots, end-4, Arch scripts) rely on dirty `curl | bash` pipelines that install unpinned packages, pollute your home directory, and silently break on subsequent system updates. This setup is built from first principles on NixOS:

- **100% Declarative & Bitrot-Proof**:
  - Zero ad-hoc packages or untracked state. Every package, driver, daemon, user permission, font, and config file is locked deterministically via Nix Flakes.
  - Generational rollbacks (`sudo nixos-rebuild --rollback`): If an upstream package ever misbehaves, you can boot back into your previous known-good state with zero downtime.
- **Native Event-Driven IPC (Eliminating Polling Wakeups)**:
  - Generic rice configurations often run periodic `while true; do sleep 1; ... done` bash loops to poll volume, brightness, battery, and workspaces.
  - This setup uses direct event-driven IPC inside QuickShell: Hyprland socket events (~6ms response), PipeWire D-Bus signals (~8ms audio reactivity), and Linux kernel uevents via `udevadm`. UI state updates reactively without unnecessary background timer wakeups.
- **Hardware-Enforced Battery & Power Policy**:
  - **TLP 1.9.1 Hardware Authority**: Governs CPU EPP scaling, platform profiles, ASPM, and enforces an 80% battery charging ceiling (`charge_control_end_threshold = 80`) directly at the firmware level to extend battery health.
  - **Dynamic GPU Shader Bypass**: On `power-saver` mode or black wallpapers, Hyprland automatically bypasses dual-kawase blur shaders, drop shadows, and forces 100% opaque window rendering. This eliminates multi-pass alpha-blending and saves ~1.2W–2.0W of GPU package power during typing and scrolling.
  - **Instant Gaming / Low-Latency Mode (`SUPER + SHIFT + G`)**: Direct scanout (`render:direct_scanout = 2`), Adaptive Sync (VRR), and asynchronous tearing without compositor lag.
- **Zero-Blink Compositor Hot-Reloads**:
  - Reloading Hyprland (`SUPER + R`) evaluates configuration state synchronously at Frame-0. It does not unmap Wayland surfaces or cold-restart the desktop shell, eliminating black screen flashes and dropping reload time to ~15ms.
- **Dynamic Material You Theming**:
  - Instant palette extraction via Matugen on wallpaper changes with inotify synchronization, updating QuickShell widgets, terminal, and launcher without daemon overhead.

---

## Architecture & System Structure

The repository separates hardware topology, declarative system modules, user environment, and standalone dotfiles:

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
│       ├── default.nix                # Host-level imports & machine metadata
│       └── hardware-configuration.nix # Kernel modules, filesystems, and hardware drivers
├── modules/
│   ├── system/                        # Declarative NixOS system services
│   │   ├── asus-brightness-rebind.nix # Hardware brightness hotkey mapping
│   │   ├── boot.nix                   # systemd-boot EFI & kernel parameter tuning
│   │   ├── fonts.nix                  # CJK, monospace, and Nerd Font typography
│   │   ├── gaming.nix                 # Low-latency gaming kernel & graphics stack
│   │   ├── memory.nix                 # ZRAM & memory pressure handling
│   │   ├── packages.nix               # System-wide CLI & GUI package manifests
│   │   ├── power.nix                  # TLP power management & battery charge thresholds
│   │   ├── services.nix               # NetworkManager, PipeWire, udev, & D-Bus daemons
│   │   └── users.nix                  # User account privileges & sudo rules
│   └── home/                          # User-space Home Manager modules
│       ├── desktop-entries.nix        # Curated application launcher overrides
│       ├── shell.nix                  # Zsh environment, custom rebuild() gate & aliases
│       ├── spicetify.nix              # Declarative Spotify theming
│       ├── theme.nix                  # GTK, icon, and cursor theming
│       └── vscodium.nix               # VSCodium configuration & extensions
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

## Installation & Setup

### 1. Prerequisites (Fresh Machine)
Ensure NixOS is installed and Flakes are enabled in `/etc/nixos/configuration.nix`:
```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

### 2. Clone & Adapt Hardware
```bash
git clone https://github.com/Realdhiru/nix.git ~/nix
cd ~/nix

# Generate hardware configuration for your target machine
nixos-generate-config --show-hardware-config > hosts/nixos/hardware-configuration.nix
```

### 3. Initial Build & Activation
```bash
# Build and activate the flake configuration
sudo nixos-rebuild switch --flake .#nixos
```

### 4. Workflow After Activation
Once active, the built-in protected rebuild wrapper handles git commits, safety builds, activation gates, and rollback tagging automatically:
```bash
rebuild "your commit message"
```

---

## Credits & Built With

This desktop experience is built upon an incredible ecosystem of open-source tools:

- **[NixOS](https://nixos.org)** — Declarative system foundations & package reproducibility.
- **[Hyprland](https://hyprland.org)** by Vaxry — Smooth, dynamic Wayland tiling compositor.
- **[QuickShell](https://git.outfoxxed.me/outfoxxed/quickshell)** by Outfoxxed — High-performance QML Wayland layer-shell framework.
- **[serpantinum](https://github.com/ilyamiro/serpantinum)** by ilyamiro — Base QuickShell widget foundation, adapted and optimized with native IPC for personal daily driving.
- **[Matugen](https://github.com/InioX/matugen)** by InioX — Material You dynamic color palette generation.
- **[Fuzzel](https://codeberg.org/dnkl/fuzzel)** by Daniel Eklöf — Minimal, lightweight Wayland application launcher.
- **[WezTerm](https://wezfurlong.org/wezterm/)** by Wez Furlong — GPU-accelerated terminal emulator.
- **[Starship](https://starship.rs)** — Fast, customizable cross-shell prompt.
- **[PipeWire & WirePlumber](https://pipewire.org)** — Low-latency audio architecture.
- **[TLP](https://linrunner.de/tlp/)** — Advanced Linux power management and battery charge control.
- **[gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/about/)** by decman — High-performance hardware video recording.
- **[Fastfetch](https://github.com/fastfetch-cli/fastfetch)** by LinusDierheimer — Neofetch-compatible system information tool.