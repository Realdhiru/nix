---
title: System Architecture Map of Content
type: moc
tags: [moc, architecture, nixos, overview, index]
status: permanent
created: 2026-10-17
last_updated: 2026-10-18
---

# System Architecture Map of Content

This repository houses a declarative, reproducible Linux desktop built on NixOS, configured with Hyprland through modular Lua scripts, powered by custom QuickShell QML desktop widgets, and styled using Wallust dynamic color generation.

This document serves as the master index to the system architecture, design specifications, and engineering rationale.

---

## Live Knowledge Feeds
- **[[Recent Updates]]** — Rolling feed of recently modified notes, new architectural additions, and technical refactors.

---

## Core System Domains

### 1. The Why & Nix Philosophy
Foundational architectural decisions, trade-offs between imperative and declarative systems, and configuration mechanics.
- [[Why NixOS Over Arch and Debian]] — Analysis of mutable state drift vs functional reproducibility.
- [[Why Flakes Over Legacy Nix Channels]] — Pinned lockfiles, pure evaluation, and dependency tracking.
- [[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]] — The two core ways to manage config files in Nix and why our desktop uses a hybrid model.
- [[Home Manager vs System Configuration]] — Clear separation of concerns between machine privilege and user workflow.

### 2. Flake & System Architecture
Structural organization of the Nix codebase, Flake specifications, packaging blueprints, and repository boundaries.
- [[Nix Flakes - Deep Dive Specification, Anatomy, and Evaluation]] — Complete breakdown of the flake schema, input URI types, `follows` overrides, and lockfile invariants.
- [[How to Create a Standalone Flake for Any Software]] — Step-by-step production blueprints for packaging proprietary binaries, C/C++ CMake projects, Rust Cargo applications, and Electron apps.
- [[Root Flake Topology]] — Dependency graph, Nixpkgs inputs, overlays, and system outputs.
- [[Flake Self-Hosting Architecture]] — Why we fork fast-moving binary flakes to defend against upstream hash drift.
- [[Host Configuration Anatomy]] — Kernel parameters (`i915`), fastboot, swapfile resume offsets, and hardware modules.
- [[Application Packaging - Derivations, FHS, AppImage, and Wrappers]] — The 4 mechanisms for running software on NixOS (Patchelf, FHS sandboxes, kernel `binfmt_misc` AppImages, and `makeWrapper`).

### 3. Compositor & Hyprland Engine
The Wayland display tier and window management pipeline.
- [[Hyprland Architecture]] — Dynamic tiling, Aquamarine DRM backend, and multi-monitor OLED management.
- [[Lua Configuration Model]] — Why we replaced monolithic `hyprland.conf` with modular Lua scripts.
- [[Compositor Rules & Opacity]] — Multi-tier glassmorphism hierarchy, Solid Mode overrides, and layer surface blur.
- [[Display Protocols - X11 vs Wayland, XWayland, and Electron Scaling]] — Why XWayland blurs on HiDPI/OLED screens and how `NIXOS_OZONE_WL` forces native subpixel rendering.

### 4. QuickShell QML Desktop
The native C++ and Qt/QML desktop shell.
- [[QuickShell Event-Driven IPC]] — Eliminating periodic bash polling loops with native C++ event signals.
- [[TopBar & Dynamic Workspaces]] — Single-flight debounce timers and content-derived music layout math.
- [[Widgets Breakdown]] — Architecture of our battery dial, radial network manager, carousel, and popup cards.

### 5. Theming & Wallust Engine
Dynamic color extraction and semantic design tokens.
- [[Wallust Dynamic Palette Engine]] — K-Means clustering in Lch colorspace and why Matugen was retired.
- [[Theme.qml & Semantic Roles]] — Mapping raw ANSI palette outputs into reactive QML design tokens.

### 6. Power & Hardware Authority
Power arbitration, battery life engineering, and machine quirks on the ASUS Vivobook S 15 OLED.
- [[TLP Exclusive Authority]] — TLP 1.9.1 as the single source of truth for power profiles and governors.
- [[Race-to-Sleep Strategy]] — The physics of CPU C-states and why clock throttling harms battery efficiency.
- [[Thermal and Battery Engineering - EPP, ASPM, Turbo, and C-States]] — Intel P-State Speed Shift, PCIe ASPM link states, TB4 D3cold traps, and GPU framebuffer compression.
- [[ASUS Hardware Quirks]] — 80% charge ceiling, OLED brightness key rebind hooks, and lid switch behavior.
- [[Coffee Mode]] — Persistent systemd idle inhibitor state engine across reloads and reboots.

### 7. Audio & Media Pipeline
Low-latency DSP and desktop media telemetry.
- [[Linux Audio Architecture - ALSA, PulseAudio, PipeWire, and WirePlumber]] — 25-year evolution of the Linux audio stack, zero-copy memory graphs, and WirePlumber policies.
- [[Native PipeWire 10-Band Equalizer]] — Built-in biquad filter-chain replacing the bloated EasyEffects daemon.
- [[MPV MPRIS Pipeline]] — Declarative C plugin symlinks surviving garbage collection passes.

### 8. Operational Flow & Recovery
Reliability, health verification, and rollback pipelines.
- [[The rebuild() Function]] — 4-stage atomic build, switch, and verification pipeline.
- [[Automated Rollback Safeguards]] — Headless test harness verifying compositor and terminal health.
- [[Emergency Recovery Protocol]] — Low-level TTY recovery, audio resets, and QuickShell process recovery.

### 9. Battle-Tested Tacit Knowledge
Non-obvious pitfalls, race conditions, and hardware traps discovered in production.
- [[Intel GPU Ring Buffer Trap]] — Avoiding Aquamarine DRM page-flip crashes on Intel Iris Xe graphics.
- [[Lockscreen Testing Prohibition]] — Why headless PAM testing causes unrecoverable session lockups.
- [[QML Scene-Graph Coordinate Gating]] — Fixing Frame-0 layout jumps and geometry clamping glitches.
- [[Python Ban in Interactive Paths]] — Enforcing sub-5ms latency across interactive desktop actions.

### 10. Showcase & Pitch Playbook
- [[The 5-Minute Distro Showcase]] — Structured script and presentation guide for technical demos and walkthroughs.
