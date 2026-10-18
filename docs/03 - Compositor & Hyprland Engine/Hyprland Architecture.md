---
title: Hyprland Architecture
tags: [compositor, hyprland, wayland, rendering, aquamarine, vrr]
---

# Hyprland Architecture

Hyprland serves as the Wayland display server and window compositor for this system. It is implemented in C++ and utilizes the modern **Aquamarine** rendering backend.

This document details the rendering pipeline, input latency characteristics, and display server configuration.

---

## 1. The Rendering Pipeline

On traditional X11 window managers (i3, bspwm, AwesomeWM), window composition relies on external compositors (like Picom/Compton), introducing frame latency, visual tearing, and inconsistent multi-monitor refresh rates.

### Wayland & Aquamarine Advantages
- **Direct VBLANK Synchronization**: Hyprland synchronizes composition directly to display scanout intervals. On our **2.8K 120Hz OLED** panel, animations, cursor motion, and window transitions execute at a constant 120 FPS without tearing.
- **Hardware-Accelerated Dual-Kawase Blur**: Multi-pass blur shaders are compiled into OpenGL/Vulkan pipelines executed directly on the Intel GPU, avoiding CPU rendering bottlenecks.
- **Socket-Based IPC**: Exposes real-time compositor events via a dedicated UNIX domain socket (`/run/user/1000/hypr/<his>/.socket2.sock`), enabling external shells like QuickShell to receive workspace and window focus events in under 6 milliseconds.

---

## 2. Low-Latency Gaming Pipeline

When running performance-critical workloads or full-screen gaming (e.g., Proton / Lutris titles), desktop composition can be bypassed on demand (`SUPER + SHIFT + G`):

- **Direct Scanout (`render:direct_scanout = 2`)**: Allows full-screen game surfaces to scan out directly to the display controller, bypassing the compositor framebuffer and reducing input latency to zero.
- **Adaptive Sync (VRR)**: Dynamically adjusts display refresh rates to match rendering framerates, eliminating stutter and frame pacing jitter.
- **Asynchronous Tearing**: Selectively allowed on full-screen surfaces for competitive low-latency applications.
- **Automated Blur Bypass**: Compositor blur and transparency passes are suppressed, redirecting 100% of GPU compute to the game engine.

## Related Nodes
- [[Lua Configuration Model]]
- [[Compositor Rules & Opacity]]
- [[Intel GPU Ring Buffer Trap]]
