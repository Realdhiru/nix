# ❄️ NixOS + Hyprland Desktop

<div align="center">

[![NixOS](https://img.shields.io/badge/NixOS-Unstable-blue?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland-00B4D8?style=for-the-badge&logo=hyprland&logoColor=white)](https://hyprland.org)
[![QuickShell](https://img.shields.io/badge/UI-QuickShell_(QML)-8338EC?style=for-the-badge)](https://git.outfoxxed.me/outfoxxed/quickshell)
[![Theming](https://img.shields.io/badge/Theme-Wallust-FF006E?style=for-the-badge)](https://codeberg.org/explosion-mental/wallust)
[![Flakes](https://img.shields.io/badge/Config-Nix_Flakes-52B788?style=for-the-badge&logo=nixos)](https://wiki.nixos.org/wiki/Flakes)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

<p align="center">
  A declarative Wayland desktop for NixOS, Hyprland, and custom QuickShell widgets. Hardware facts are isolated per host; the current flake targets x86_64-linux.
</p>

</div>

---

## 🌟 QuickShell Desktop Widgets & Features

Custom QML widgets built natively on [QuickShell](https://git.outfoxxed.me/outfoxxed/quickshell), driven by Wayland events with bounded sampling for live statistics:

<table>
  <tr>
    <td width="50%" align="center">
      <b>Wallpaper Picker & Downloader</b><br/>
      <img src="docs/assets/wallpaper_carousel.webp" alt="Wallpaper Picker" width="100%" /><br/>
      <sub>3D parallax carousel with wallpaper browsing, favorites tracking (`\`), online search & download, and instant switching.</sub>
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
| **OS & Packages** | [NixOS](https://nixos.org) (Unstable) + [Flakes](https://wiki.nixos.org/wiki/Flakes) | Atomic, fully declarative system configuration with automated rollback gates |
| **Compositor** | [Hyprland](https://hyprland.org) | Wayland dynamic compositor with continuous scrolling ribbon (`scrolling.lua`) & Dwindle mode parity (`SUPER + F10`) |
| **Desktop Shell** | [QuickShell](https://git.outfoxxed.me/outfoxxed/quickshell) (Qt6 / QML) | Event-driven UI with exclusive focus grab (`WlrKeyboardFocus`); FocusTime and battery audit use bounded sampling |
| **Theming** | [Wallust](https://codeberg.org/explosion-mental/wallust) | Sub-millisecond wallpaper-derived color extraction across UI, terminals & GTK |
| **Audio Engine** | [PipeWire](https://pipewire.org) (`filter-chain`) | Low-latency audio routing with 10-band C DSP equalizer, spectral vocal subtraction LADSPA plugin, & smart volume ceilings |
| **Power Engine** | [TLP 1.10.2](https://linrunner.de/tlp/) | Firmware battery threshold (80%), TLP-owned profiles, deep C-states, & 802.11 Wi-Fi power-save |
| **Launchers** | [Fuzzel](https://codeberg.org/dnkl/fuzzel) | Frosted glass app launcher, instant file search & emoji/glyph picker |
| **Knowledge Base** | [Obsidian](https://obsidian.md) | Native Wayland markdown second-brain vault with interactive graph view |

---

## ⌨️ Desktop Keybindings

Standardized keybind conventions organized into distinct functional tiers:

| Tier | Keybinding | Action |
| :--- | :--- | :--- |
| **Daily Core** | `SUPER + A` / `SUPER + SPACE` | App Launcher / Instant File Search |
| | `SUPER + T` / `SUPER + B` / `SUPER + E` / `SUPER + C` | Terminal (Alacritty) / Browser / File Manager / Editor |
| | `SUPER + Q` | Close focused window gracefully (`Actions::closeWindow`) |
| | `SUPER + F10` | Toggle dual layout (Dwindle $\leftrightarrow$ Continuous Scrolling Ribbon) |
| **Daily Widgets** | `SUPER + N` / `SUPER + U` / `SUPER + V` / `SUPER + M` / `SUPER + F` | Toggle Network / Battery / Clipboard / Music / Focus Timer |
| | `SUPER + L` | Toggle Light / Dark quickshell theme mode |
| **Secondary Widgets** | `SUPER + SHIFT + W` / `SUPER + SHIFT + N` / `SUPER + SHIFT + M` / `SUPER + SHIFT + A` | Toggle Wallpaper Picker / Calendar / Display Manager / Sunset Tint |
| | `SUPER + SHIFT + X` | Fast offline OCR region capture to clipboard |
| | `\` (in Wallpaper Picker) | Toggle favorite wallpaper |
| **Web Applications** | `SUPER + ALT + W` / `Y` / `C` / `A` / `N` / `D` / `G` | Launch WhatsApp / YouTube / ChatGPT / Claude / Notion / To-Do / Antigravity |
| **Hardware & Recovery**| `SUPER + F6` / `SUPER + F7` / `SUPER + F8` | Fix Audio Graph / Recover Bluetooth Daemon / Restart Wi-Fi Radio |
| | `SUPER + R` | Instant live reload of compositor, quickshell, and themes |

---

## 🚀 Quick Start

Built for **portable x86_64-linux NixOS hosts** — generate host facts, edit personal defaults, and keep machine-specific details out of shared modules:

1. **Enable Flakes** in `/etc/nixos/configuration.nix`:
   ```nix
   nix.settings.experimental-features = [ "nix-command" "flakes" ];
   ```
2. **Clone & Configure Identity**:
   ```bash
   git clone https://github.com/Realdhiru/nix.git ~/nix
   cd ~/nix
   nix run .#init-host -- <host-name>
   git add hosts/<host-name>/hardware-configuration.nix hosts/<host-name>/system.nix
   ```
   *Review the generated files, then edit [`user.nix`](user.nix) for identity and personal preferences. Hostname and hardware facts belong in `hosts/<host>/system.nix`.*
3. **Manual first installation** (before the `rebuild` shell function is installed):
   ```bash
   sudo nixos-rebuild switch --flake ~/nix#nixos
   ```
   For later changes, use `rebuild`; it runs `nix flake check`, builds the current tree, switches, runs the health check, and rolls back on critical failure. Only `rebuild -c [message]` optionally commits files already staged by you after a successful switch; it never stages files itself, ignores unrelated unstaged work, rejects unknown arguments, and stops if a staged file also has unstaged edits.

### Configuration layers and new hosts

- `modules/` and `dotfiles/` hold shared implementation. Hardware-sensitive behavior reads runtime capabilities or receives facts from a host module.
- `hosts/<host>/hardware-configuration.nix` and `system.nix` hold generated machine facts and hardware quirks.
- `user.nix` holds identity, home directory, locale, keyboard, theme, app defaults, wallpaper paths, and personal power/audio preferences.
- Battery-specific TLP profile permissions and settings are emitted only for hosts whose generated facts include a battery.
- The retained USB autosuspend workaround is one personal setting that controls both the kernel argument and TLP policy.
- The shared `refresh_monitor.sh` applies AC/battery refresh from Hyprland's advertised modes and the saved monitor intent; it resolves data before one `hl.monitor()` IPC call, and is used by power events, startup, and profile changes.
- QuickShell startup, reload, and its full-shell toggle are serialized through `qs_manager.sh` to keep one `Shell.qml` instance.
- FocusTime persists buffered samples transactionally and retains them for retry after database errors; its Rust crate and popup live together under the widget folder.
- Home-managed application launchers use the selected Nix package paths rather than hardcoded system-profile binaries.
- `home.nix` is the Home Manager entry point; `modules/home/desktop.nix` composes the remaining desktop setup with focused audio, monitor, QuickShell, wallpaper, shell, theme, and state modules. TLP hardware policy stays in `modules/system/power.nix`.
- QuickShell widgets keep their QML and feature-specific helpers together under `dotfiles/hypr/scripts/quickshell/<feature>/`; shared desktop helpers remain under `dotfiles/hypr/scripts/`.
- Wallust writes palette data to `~/.cache/theme/`; the Fuzzel launcher reads that palette for runtime colors instead of rewriting the tracked `fuzzel.ini`.
- Power Saver pauses decorative QuickShell loops and title marquees while leaving status indicators available.
- To add a host, run `nix run .#init-host -- <name>` from this repository. Review both generated files and add them explicitly with `git add`; the flake ignores untracked host files.

---

## 🧭 System Management Commands

Custom shell workflows defined in [`modules/home/shell.nix`](modules/home/shell.nix):

| Command | Description |
| :--- | :--- |
| `rebuild` | Runs flake checks, builds and switches the current tree, then runs the health gate and automatic rollback; never stages or commits |
| `update` | Update flake inputs (`nixos-unstable`) and trigger verified rebuild |
| `gens` | List annotated, color-coded system generations with active/stable markers |
| `pin-stable [gen]` | Permanently pin a generation as a GC root (`/nix/var/nix/gcroots/boot-stable`) |
| `clean` | Safely delete unpinned store paths older than 14 days |
| `gameclean [-y] [--include-unmanaged-prefixes]` | Preview or clean Wine/Proton caches; unreferenced prefixes require explicit opt-in |
| `scripts/selftest-modes.sh --live` | Explicitly run the mode-transition test; it changes live desktop modes |
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
