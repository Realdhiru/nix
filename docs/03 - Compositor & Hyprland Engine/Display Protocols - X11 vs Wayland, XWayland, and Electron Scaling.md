---
title: Display Protocols - X11 vs Wayland, XWayland, and Electron Scaling
tags: [wayland, x11, xwayland, electron, scaling, hidpi, oled, architecture]
---

# Display Protocols: X11 vs Wayland, XWayland, and Electron Scaling

When running modern high-resolution laptop displays (specifically our **2.8K 120Hz OLED** at $2880 \times 1800$), the difference between the legacy X11 protocol and native Wayland is the difference between a blurry, tearing desktop and razor-sharp, sub-pixel rendering.

This document details the architectural mechanisms separating X11, Wayland, and XWayland, and explains the engineering choices behind our Chromium and Electron configuration.

---

## 1. The Core Architectural Differences: X11 vs Wayland

```
Legacy X11 Architecture:
[Client] ──▶ [X Server] ──▶ [Window Manager] ──▶ [Compositor (Picom)] ──▶ [Kernel DRM/KMS]
(Every frame passes through 3 separate processes; introduces tearing and frame latency)

Modern Wayland Architecture:
[Client] ──▶ [Hyprland Compositor & Display Server] ──▶ [Kernel DRM/KMS]
(Direct single-hop composition; every frame is perfectly synchronized to VBLANK)
```

### 1. "Every Frame is Perfect"
Under X11, clients draw into uncoordinated pixmaps. The window manager and compositor attempt to stitch them together after the fact. If an application updates its buffer mid-scanout, the user sees horizontal screen tearing.
Under Wayland, the client renders into a private buffer (`wl_buffer`) and passes a handle to Hyprland. Hyprland composite surfaces and presents them atomically during the display's VBLANK interval. Screen tearing is physically impossible unless explicitly requested for gaming (`async_tearing`).

### 2. Multi-DPI and Fractional Scaling
- **X11**: The entire X screen is forced to a single global DPI value. If you plug a 4K external monitor into a 1080p laptop, windows are either microscopically small on the laptop or gigantic on the external screen.
- **Wayland**: Each display (`wl_output`) owns its independent scale factor and refresh rate.

---

## 2. The Trap of XWayland and Blurry Scaling

Many legacy applications (and unconfigured Electron apps) cannot speak the Wayland protocol natively. To maintain backward compatibility, Hyprland runs an embedded X server: **XWayland**.

### What Happens When an App Runs on XWayland on a HiDPI Screen:
1. The application queries XWayland and renders at integer scale factor $1\times$ (thinking it is on a standard 1080p screen).
2. Hyprland detects that the laptop display has a fractional scale factor (e.g. $1.33\times$ or $1.5\times$).
3. Because the X11 app cannot scale itself fractionally, Hyprland takes the application's rendered 2D bitmap and **bilinearly upscales it on the GPU**.
4. **The Result**: Text becomes blurry, fonts lose sharpness, sub-pixel antialiasing is destroyed, and the display looks like an out-of-focus photograph on a 2.8K OLED screen.

---

## 3. Our Solution: Native Ozone Wayland Automation

To ensure that Chromium, Electron, and Web-based applications render natively at true display resolution with crisp font rendering and kinetic touchpad gestures:

### The Global Invariant: `NIXOS_OZONE_WL = "1"`
In `hosts/nixos/default.nix`:
```nix
environment.sessionVariables = {
  NIXOS_OZONE_WL = "1";
};
```

### How Chromium/Electron Intercepts This:
1. Chromium's modern display abstraction layer is called **Ozone**.
2. Upstream Nixpkgs packages Electron and Chromium applications with intelligent wrapper scripts.
3. When `NIXOS_OZONE_WL = "1"` is detected in the environment and `WAYLAND_DISPLAY` is present:
   - The wrapper automatically injects `--ozone-platform=wayland`.
   - It appends `--enable-wayland-ime=true` for input method support.
   - It appends `--wayland-text-input-version=3`.

### The Practical Result
- **Obsidian, Brave, ChatGPT Desktop, and Discord** launch as native Wayland surfaces.
- Fractional scaling and font hinting render with zero blurriness.
- Native two-finger smooth kinetic scrolling and touchpad pinch-to-zoom operate at a locked 120Hz.

## Related Nodes
- [[Hyprland Architecture]]
- [[Host Configuration Anatomy]]
- [[Application Packaging - Derivations, FHS, AppImage, and Wrappers]]
