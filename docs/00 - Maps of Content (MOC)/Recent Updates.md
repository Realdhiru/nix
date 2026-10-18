---
title: Recent Knowledge Updates
type: feed
tags: [moc, updates, changelog, feed]
status: permanent
last_updated: 2026-10-18
---

# Recent Knowledge Updates Feed

A rolling feed of recent technical deep dives, architectural refactors, and systems documentation added or updated across this repository.

Whenever a component is modified in code, its corresponding documentation entry is indexed here and logged in [[../CHANGELOG.md|CHANGELOG.md]].

---

## Latest Updates: 2026-10-18

### 1. Second-Brain & Knowledge Vault Integration
- **[[Declarative Configuration - In-Store Derivations vs Out-of-Store Symlinks]]**: Exhaustive architectural comparison of in-store derivations (read-only immutability, 45s rebuild latency) vs `mkOutOfStoreSymlink` (instant live UI reload), and the hybrid deployment model.
- **[[Application Packaging - Derivations, FHS, AppImage, and Wrappers]]**: Complete breakdown of the 4 mechanisms for running software on NixOS without standard FHS directories (`autoPatchelfHook`, `buildFHSEnv`, kernel `binfmt_misc` AppImages, and `makeWrapper`).
- **[[Nix Flakes - Deep Dive Specification, Anatomy, and Evaluation]]**: Formal specification of RFC 0049, input URL schemas, the `inputs.nixpkgs.follows` deduplication rule, and lockfile cryptographic NAR hashes.
- **[[How to Create a Standalone Flake for Any Software]]**: Step-by-step production blueprints for packaging upstream proprietary binaries, CMake C++ projects, Cargo Rust applications, and Electron desktop apps.
- **[[Linux Audio Architecture - ALSA, PulseAudio, PipeWire, and WirePlumber]]**: 25-year evolution from raw ALSA locks to PulseAudio/JACK fragmentation, and why PipeWire's zero-copy memory graph won.
- **[[Display Protocols - X11 vs Wayland, XWayland, and Electron Scaling]]**: Why XWayland blurs on 2.8K OLED screens (GPU bilinear upscaling) and how `NIXOS_OZONE_WL = "1"` automates native subpixel rendering.
- **[[Thermal and Battery Engineering - EPP, ASPM, Turbo, and C-States]]**: Intel P-State Speed Shift, EPP biases, avoiding the `EBUSY` governor trap, PCIe ASPM link states (`powersupersave`), and Intel GPU Framebuffer Compression saving ~2.2 GB/s memory bandwidth.

### 2. Operational & Failure-Mode Post-Mortems
- **[[Intel GPU Ring Buffer Trap]]**: Root cause analysis of `rcs0` ring buffer saturation on Intel Iris Xe graphics causing Aquamarine DRM page-flip crashes into Safe Mode, and the mandatory 1.5s debounce rule.
- **[[Lockscreen Testing Prohibition]]**: Why headless PAM testing causes orphaned session descriptors and unrecoverable lockups.
- **[[QML Scene-Graph Coordinate Gating]]**: How preloading offscreen (`visible: false`) resolves width to 0 and causes Frame-0 layout snaps.
- **[[Python Ban in Interactive Paths]]**: Enforcing sub-5ms interactive desktop hot paths by replacing slow Python interpreters with native C/C++ bindings and POSIX utilities.

---

## Navigation & Quick Filters
- **Master Nexus**: [[System Architecture MOC]]
- **Philosophy**: [[The Why & Nix Philosophy MOC]]
- **Flakes & Code**: [[Flake & System Architecture MOC]]
- **Compositor**: [[Compositor & Hyprland MOC]]
- **Widgets**: [[QuickShell Desktop MOC]]
- **Power**: [[Hardware & Power Authority MOC]]
- **Audio**: [[Audio & Media Pipeline MOC]]
- **Recovery**: [[Operational Flow & Recovery MOC]]
- **Presentation**: [[The 5-Minute Distro Showcase]]
