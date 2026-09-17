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

## Installation

```bash
# Clone the configuration
git clone https://github.com/Realdhiru/nix.git ~/nix
cd ~/nix

# Switch to the generation
nh os switch ~/nix
```

---

## Credits & Acknowledgments

- **[QuickShell](https://git.outfoxxed.me/outfoxxed/quickshell)** by Outfoxxed for the QML Wayland desktop shell framework.
- This project uses some QuickShell widgets from **[ilyamiro/serpantinum](https://github.com/ilyamiro/serpantinum)**, adapted and optimized with native event-driven IPC for personal use.
- **[Matugen](https://github.com/InioX/matugen)** for dynamic Material You color extraction.
- **[Hyprland](https://hyprland.org)** for the smooth Wayland compositor.