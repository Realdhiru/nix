# ❄️ NixOS & Hyprland Rice

<div align="center">

[![NixOS](https://img.shields.io/badge/NixOS-25.05-blue?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00B4D8?style=for-the-badge&logo=hyprland&logoColor=white)](https://hyprland.org)
[![QuickShell](https://img.shields.io/badge/UI-QuickShell_(QML)-8338EC?style=for-the-badge)](https://git.outfoxxed.me/outfoxxed/quickshell)
[![Theming](https://img.shields.io/badge/Theme-Matugen-FF006E?style=for-the-badge)](https://github.com/InioX/matugen)
[![Flakes](https://img.shields.io/badge/Config-Nix_Flakes-52B788?style=for-the-badge&logo=nixos)](https://wiki.nixos.org/wiki/Flakes)

<p align="center">
  <b>A declarative, reproducible Wayland desktop engineered for ultra-low latency, crisp HiDPI aesthetics, and intelligent battery efficiency.</b>
</p>

</div>

---

## 📸 Showcase

<div align="center">

<!-- Place your screenshots / recordings inside docs/assets/ -->

### 🖥️ Desktop & Interface
<img src="docs/assets/hero_desktop.png" alt="Desktop Overview" width="850" />

<br/>

| ⚡ Control Center | 📶 Network Panel |
| :---: | :---: |
| <img src="docs/assets/battery_control_center.png" alt="Control Center" width="410" /> | <img src="docs/assets/wifi_network_panel.png" alt="Network Panel" width="410" /> |

| 🚀 Centered Launcher | 🔍 Fast File Search |
| :---: | :---: |
| <img src="docs/assets/fuzzel_launcher.png" alt="Fuzzel Launcher" width="410" /> | <img src="docs/assets/fuzzel_file_search.png" alt="Fuzzel File Search" width="410" /> |

</div>

---

## ✨ Key Features

- **⚡ Native Event-Driven QuickShell UI**:
  - Direct C++ IPC bindings for Hyprland workspaces (6ms), PipeWire audio (8ms), and direct sysfs watchers.
  - Zero periodic bash polling loops for minimal CPU wakeups and extended battery runtime.
  - Modularized, debloated widget suite curated specifically for everyday productivity.

- **🎨 Dynamic Material You Theming**:
  - Live color palette extraction via **Matugen** on wallpaper transitions.
  - Sub-10ms atomic color syncing across QuickShell widgets, terminal, and launcher.

- **🔋 Power & Performance Architecture**:
  - **TLP 1.9.1 Hardware Authority**: Fine-tuned CPU EPP, ASPM, and 80% battery charging ceiling.
  - **Dynamic GPU Shader Bypass**: Disables dual-kawase blur, drop shadows, and forces 100% opaque rendering on `power-saver` or black wallpapers, eliminating GPU alpha-blending and saving ~1.2W–2.0W package power.
  - **Gaming / Low-Latency Mode (`SUPER + SHIFT + G`)**: Instantly enables Direct Scanout, Adaptive Sync (VRR), and tearing with zero compositor overhead.

- **🚀 Streamlined App Launcher & File Search**:
  - Centered **Fuzzel** launcher tuned for 2x HiDPI displays.
  - Fast interactive file finder (`SUPER + SPACE`) with instant parent directory navigation.
  - Layer-shell on-demand focus with instant outside-click dismissal.

- **🌐 Robust Native Networking**:
  - Native NetworkManager integration for instant Wi-Fi scanning and connection handling.
  - Hotspot management with client tracking and auto-reconnect on shutdown.

---

## ⌨️ Keybindings

| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `SUPER + Enter` | Terminal | Launch WezTerm |
| `SUPER + A` | App Launcher | Open centered Fuzzel application menu |
| `SUPER + SPACE` | File Finder | Fast interactive file search |
| `SUPER + Q` | Close Window | Close active window |
| `SUPER + SHIFT + G` | Gaming Mode | Toggle low-latency compositing & zero blur |
| `SUPER + SHIFT + F` | Pin Window | Toggle floating window pin |
| `SUPER + R` | Reload Config | Hot-reload Hyprland without screen blink |
| `SUPER + 1..6` | Workspaces | Switch active workspace |

---

## 📂 Repository Structure

```text
nix/
├── flake.nix              # Flake entrypoint & inputs
├── hosts/
│   └── zephyrus/          # Host-specific hardware & system config
├── modules/
│   ├── system/            # Core NixOS modules (audio, display, packages, tlp)
│   └── home/              # Home Manager configs (wezterm, shell, git)
├── dotfiles/
│   ├── hypr/              # Hyprland Lua configuration & scripts
│   │   └── scripts/quickshell/ # Curated QuickShell QML widgets
│   └── fuzzel/            # Fuzzel HiDPI configuration
└── docs/
    ├── assets/            # Showcase images & videos
    └── decisions.md       # Architecture & engineering decisions log
```

---

## 🛠️ Installation & Reproduction

> [!WARNING]
> This configuration is tailored for my specific hardware (ASUS ROG Zephyrus / Intel + NVIDIA / HiDPI display). Adapt hardware modules before building on different machines.

```bash
# Clone the repository
git clone https://github.com/Realdhiru/nix.git ~/nix
cd ~/nix

# Test build
nh os build ~/nix

# Switch to the new generation
nh os switch ~/nix
```

---

## 💖 Credits & Acknowledgments

- **[QuickShell](https://git.outfoxxed.me/outfoxxed/quickshell)** by Outfoxxed for the flexible QML Wayland desktop shell.
- **Upstream QuickShell Widgets**: The base widget foundation was adapted from the community and heavily reworked, debloated, and optimized with native event-driven IPC for personal daily driving.
- **[Matugen](https://github.com/InioX/matugen)** for dynamic Material You color extraction.
- **[Hyprland](https://hyprland.org)** for the smooth Wayland compositor.