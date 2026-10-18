---
title: The 5-Minute Distro Showcase
tags: [showcase, presentation, pitch, demo, runbook]
---

# The 5-Minute Distro Showcase: Developer Presentation Guide

A structured guide for presenting this custom NixOS distribution during technical demos, developer meetups, and engineering interviews.

---

## Act 1: The Problem Statement (0:00 – 1:00)

### Talking Points
- Most custom Linux desktops ("rices") are fragile, mutable configurations built on Arch or Debian.
- They look great on Reddit, but one system update frequently breaks display drivers or audio daemons.
- Furthermore, many custom desktops rely on dozens of background bash polling loops that continuously wake up CPU cores and destroy laptop battery life.
- **The Solution**: We built a complete operating system on **NixOS**—100% declarative, mathematically reproducible, with zero background shell polling and atomic rollback guarantees.

### Live Action
- Open terminal and display system topology:
  ```bash
  fastfetch
  ```

---

## Act 2: Desktop Architecture & Wayland Ergonomics (1:00 – 2:30)

### Talking Points
- The visual shell is built natively in **QuickShell (Qt6 / QML)** running on **Hyprland** with the Aquamarine DRM backend.
- The display is a **2.8K 120Hz OLED** running locked at 120 FPS.
- There are **zero shell polling loops**: QuickShell binds directly to Hyprland and PipeWire via native C++ sockets, providing sub-8ms reaction times with 0.0% idle CPU usage.

### Live Demos
1. **Interactive Carousel (`SUPER + SHIFT + \`)**:
   - Open the 3D wallpaper carousel. Show smooth parallax motion.
   - Select a wallpaper: demonstrate **Wallust** extracting colors and updating the terminal, topbar, launcher, and CAVA visualizer in under 120 milliseconds.
2. **Audio DSP Equalizer**:
   - Open the media popup. Show the rotating vinyl record.
   - Adjust equalizer sliders: explain that it operates via native PipeWire 10-band biquad filters directly in the C audio server, using 0MB extra RAM (EasyEffects decommissioned).

---

## Act 3: Power Engineering on Intel Silicon (2:30 – 3:30)

### Talking Points
- Running an advanced desktop does not require sacrificing battery life. The machine idles at ~2GB RAM and 0% CPU.
- We implemented the **Race-to-Sleep** strategy: instead of artificially throttling CPU clocks (which keeps the package energized in $C0$ active states longer), tasks burst at 4.2 GHz and immediately return to deep $C8$/$C10$ sleep packages.
- **TLP 1.9.1** acts as the single source of truth for power profiles, while **asusd** enforces an 80% charge ceiling at the firmware level to protect battery longevity.

### Live Demo
- Press `SUPER + CTRL + U`: toggle **Coffee Mode**. Point out the coffee indicator lighting up in the TopBar battery pill and explain the persistent systemd inhibitor.

---

## Act 4: The Autonomous Safety Gate (3:30 – 5:00)

### Talking Points
- How do we modify system code without fear of bricking our machine?
- We built a custom rebuild pipeline: `rebuild()`.
  1. Sandboxed pre-activation build (`nixos-rebuild build`).
  2. Generation switch.
  3. Headless health gate (`scripts/health-check.sh`): tests compositor socket, spawns an isolated terminal sandbox, and audits critical daemons.
  4. Automatic rollback within 3 seconds if any critical test fails.

### Concluding Statement
> *"This is not just a theme or a set of dotfiles. It is a self-healing, mathematically reproducible operating system engineered for high-performance development."*

## Related Nodes
- [[Why NixOS Over Arch and Debian]]
- [[QuickShell Event-Driven IPC]]
- [[TLP Exclusive Authority]]
- [[The rebuild() Function]]
