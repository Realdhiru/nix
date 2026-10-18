---
title: Compositor & Hyprland Map of Content
type: moc
tags: [moc, hyprland, compositor, wayland, index]
---

# Compositor and Hyprland Map of Content

The visual presentation tier, window tiling dynamics, and input ergonomics.

---

## Core Documents

1. [[Hyprland Architecture]]
   - Aquamarine DRM rendering backend and direct VBLANK synchronization.
   - Locked 120 FPS performance on 2.8K OLED.
   - Low-latency gaming mode (`direct_scanout = 2`, VRR, async tearing).

2. [[Lua Configuration Model]]
   - Why monolithic `hyprland.conf` was decomposed into modular Lua scripts.
   - Dynamic evaluation logic for opacity toggles and monitor profiles.
   - Frame-0 hot reloading via `SUPER + R`.

3. [[Compositor Rules & Opacity]]
   - The calibrated glassmorphism hierarchy: Deep Ambient Glass (`0.47`), Soft Glass (`0.60`), Obsidian Knowledge Base (`0.65`), Terminal (`0.70`), and Solid Override (`1.00`).
   - Anti-bleed foundation layers and layer blur rules.

4. [[Display Protocols - X11 vs Wayland, XWayland, and Electron Scaling]]
   - Fundamental architectural differences between X11 and Wayland rendering.
   - The XWayland fractional scaling blur trap on HiDPI/OLED screens.
   - Automating native Ozone Wayland execution for Electron and Chromium apps via `NIXOS_OZONE_WL`.

## Related Domains
- [[QuickShell Desktop MOC]]
- [[System Architecture MOC]]
