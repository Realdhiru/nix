# ❄️ NixOS + Hyprland Desktop

<div align="center">

[![NixOS](https://img.shields.io/badge/NixOS-Unstable-blue?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00B4D8?style=for-the-badge&logo=hyprland&logoColor=white)](https://hyprland.org)
[![QuickShell](https://img.shields.io/badge/UI-QuickShell_(QML)-8338EC?style=for-the-badge)](https://git.outfoxxed.me/outfoxxed/quickshell)
[![Theming](https://img.shields.io/badge/Theme-Wallust-FF006E?style=for-the-badge)](https://codeberg.org/explosion-mental/wallust)
[![Flakes](https://img.shields.io/badge/Config-Nix_Flakes-52B788?style=for-the-badge&logo=nixos)](https://wiki.nixos.org/wiki/Flakes)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

<p align="center">
  A fully declarative Wayland desktop environment built on NixOS, Hyprland, and custom QuickShell widgets. Portable to any machine from a single flake.
</p>

</div>

---

## 🌟 QuickShell Desktop Widgets & Features

Custom event-driven QML widgets built natively on [QuickShell](https://git.outfoxxed.me/outfoxxed/quickshell) with zero polling overhead, Wayland IPC integration, and fluid micro-animations:

<table>
  <tr>
    <td width="50%" align="center">
      <b>Wallpaper Picker & Downloader</b><br/>
      <img src="docs/assets/wallpaper_carousel.webp" alt="Wallpaper Picker" width="100%" /><br/>
      <sub>3D parallax carousel with wallpaper browsing, favorites tracking (`SUPER + SHIFT + \`), online search & download, and instant switching.</sub>
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
      <sub>Vinyl playback animation, MPRIS controls, and native 10-band PipeWire DSP equalizer.</sub>
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

<sub>Wallpapers available in [Realdhiru/wallps](https://github.com/Realdhiru/wallps). Base widgets adapted from [ilyamiro/serpantinum](https://github.com/ilyamiro/serpantinum). System idles at <b>~2 GB RAM</b> with compositor, blur shaders, wallpaper engine, and QuickShell running.</sub>

---

## 🛠️ Software Stack

| Component | Software | Description |
| :--- | :--- | :--- |
| **OS & Packages** | [NixOS](https://nixos.org) (Unstable) + [Flakes](https://wiki.nixos.org/wiki/Flakes) | Atomic, fully declarative system configuration |
| **Compositor** | [Hyprland](https://hyprland.org) | Wayland dynamic tiling compositor configured in native Lua |
| **Desktop Shell** | [QuickShell](https://git.outfoxxed.me/outfoxxed/quickshell) (Qt6 / QML) | Event-driven topbar, circular battery dial, MPRIS music & popups |
| **Theming** | [Wallust](https://codeberg.org/explosion-mental/wallust) | Sub-millisecond wallpaper-derived color extraction across UI, terminals & GTK |
| **Audio Engine** | [PipeWire](https://pipewire.org) (`filter-chain`) | Low-latency audio routing with native 10-band C DSP equalizer |
| **Power Engine** | [TLP 1.9.1](https://linrunner.de/tlp/) | Firmware battery threshold (80%), dynamic platform profiles & deep C-states |
| **Launchers** | [Fuzzel](https://codeberg.org/dnkl/fuzzel) | Frosted glass app launcher, instant file search & emoji/glyph picker |
| **Knowledge Base** | [Obsidian](https://obsidian.md) | Native Wayland markdown second-brain vault with interactive graph view |

---

## 🚀 Quick Start

Built for **100% portability** — clone, edit one file, and deploy on any machine with zero hardcoded paths:

1. **Enable Flakes** in `/etc/nixos/configuration.nix`:
   ```nix
   nix.settings.experimental-features = [ "nix-command" "flakes" ];
   ```
2. **Clone & Configure Identity**:
   ```bash
   git clone https://github.com/Realdhiru/nix.git ~/nix
   cd ~/nix
   nixos-generate-config --show-hardware-config > hosts/nixos/hardware-configuration.nix
   ```
   *Edit [`user.nix`](user.nix) to set your username, full name, and email.*
3. **Build & Activate**:
   ```bash
   sudo nixos-rebuild switch --flake .#nixos
   ```

---

## ⌨️ Common Keybindings

| Keybinding | Action |
| :--- | :--- |
| `Super + T` | Terminal (`alacritty`) |
| `Super + A` | Application Launcher (`fuzzel`) |
| `Super + SPACE` | Centered Instant File Search |
| `Super + .` | Emoji & Nerd Font Glyph Picker (`Tab` to toggle mode) |
| `Super + E` | File Manager (`pcmanfm-qt`) |
| `Super + B` | Web Browser (`brave` with native VA-API hardware acceleration) |
| `Super + R` | Frame-0 Compositor, QuickShell & Theme Reload |
| `Super + Ctrl + Shift + Q` | QuickShell Kill Switch (Terminate / Restart shell cleanly) |
| `Super + Shift + W` | QuickShell Wallpaper Picker & Downloader |
| `Super + N` / `Super + U` | Network Panel / Battery & Power Control Center |
| `Super + Shift + M` / `Super + V` | MPRIS Music Player & Equalizer / Clipboard Manager |
| `Super + Shift + Z` | Selective Area Screenshot (`grim` + `slurp`) |

---

## 🧭 System Management Commands

Custom shell workflows defined in [`modules/home/shell.nix`](modules/home/shell.nix):

| Command | Description |
| :--- | :--- |
| `rebuild [msg]` | Atomic rebuild with pre-activation compile check, health gate & automated rollback |
| `update` | Update flake inputs (`nixos-unstable`) and trigger verified rebuild |
| `gens` | List annotated, color-coded system generations with active/stable markers |
| `pin-stable [gen]` | Permanently pin a generation as a GC root (`/nix/var/nix/gcroots/boot-stable`) |
| `clean` | Safely delete unpinned store paths older than 14 days |
| `gameclean [-y]` | Wine, Proton, Lutris & umu storage janitor (scans & removes orphaned gigabytes) |
| `af` / `ff` | Animated video terminal fetcher (`anifetch`) / Fastfetch |

---

## System Documentation (`docs/`)

[`docs/`](docs/) records this machine's configuration, architecture decisions, hardware behavior, and recovery procedures. General Linux, Wayland, Nix, and NixOS learning notes live in the separate Obsidian vault at `~/Projects/Vault/nix-brain/`.

* **[MOC: System Architecture](docs/00%20-%20Maps%20of%20Content%20(MOC)/System%20Architecture%20MOC.md)** — Router hub linking all subsystems.
* **[01 - The Why & Nix Philosophy](docs/01%20-%20The%20Why%20&%20Nix%20Philosophy/)** — Local system rationale and configuration ownership.
* **[02 - Flake & System Architecture](docs/02%20-%20Flake%20&%20System%20Architecture/)** — This host's flake topology, modules, and package integrations.
* **[03 - Compositor & Hyprland Engine](docs/03%20-%20Compositor%20&%20Hyprland%20Engine/)** — Lua configuration, Frame-0 opacity evaluation, Wayland display protocols.
* **[04 - QuickShell Desktop](docs/04%20-%20QuickShell%20QML%20Desktop/)** — Event-driven IPC, dynamic Kanji workspaces, widget breakdown.
* **[05 - Theming & Wallust Engine](docs/05%20-%20Theming%20&%20Wallust%20Engine/)** — Palette extraction algorithm and semantic UI tokens.
* **[06 - Power & Hardware Authority](docs/06%20-%20Power%20&%20Hardware%20Authority/)** — TLP exclusive authority, EPP/ASPM calibration, C-states, and ASUS hardware quirks.
* **[07 - Audio & Media Pipeline](docs/07%20-%20Audio%20&%20Media%20Pipeline/)** — PipeWire 10-band DSP equalizer, MPRIS D-Bus integration, VA-API hardware decoding.
* **[08 - Operational Flow & Recovery](docs/08%20-%20Operational%20Flow%20&%20Recovery/)** — Health check test harness, rollback mechanisms, emergency recovery.
* **[09 - Battle-Tested Tacit Knowledge](docs/09%20-%20Battle-Tested%20Tacit%20Knowledge/)** — Intel GPU ring buffer traps, Python bans on hot paths, scene-graph coordinate gating.
* **[Architecture Decisions (ADR)](docs/decisions.md)** & **[Tacit Knowledge](docs/tacit_knowledge.md)** — Invariants, post-mortems, and hardware specs.
