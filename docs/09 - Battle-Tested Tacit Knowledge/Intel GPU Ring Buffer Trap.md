---
title: Intel GPU Ring Buffer Trap
tags: [trap, intel, gpu, aquamarine, hyprland, crash-analysis]
---

# Intel GPU Ring Buffer Trap: Avoiding the Safe Mode Crash

A critical hardware pitfall discovered on Intel Iris Xe / UHD integrated graphics under Wayland.

This document details the mechanics of the Aquamarine DRM page-flip crash and the architectural invariant required to prevent it.

---

## 1. Failure Sequence Analysis

When testing desktop UI scripts, developers often trigger rapid back-to-back visual transitions:
- Toggling wallpaper kill and restore in rapid shell loops.
- Issuing repeated `forceReload` IPC calls to QuickShell within sub-second intervals.
- Triggering rapid shader compile and blur pass recalculations.

On a 2.8K 120Hz display, each mode switch destroys and reallocates massive 3K texture buffers.

### The Kernel-to-Compositor Hang Chain
1. Burst allocations exhaust the Intel integrated GPU execution ring buffer (`rcs0`).
2. The kernel i915 driver emits a GPU hang:
   `i915: GPU HANG: ecode 12:1:84dffffb in QSGRenderThread; rcs0 reset request timed out`.
3. The GuC/HuC firmware reset request times out.
4. The Aquamarine DRM backend receives an unrecoverable page-flip failure.
5. Hyprland trips an internal assertion failure:
   `CHyprOpenGLImpl::begin: Assertion failed -> abort() -> SIGABRT`.
6. The entire compositor crashes, terminating all graphical applications and dumping the user into Hyprland Safe Mode.

---

## 2. The Architectural Invariant: Mandatory Pacing Delays

- **Serialization & Settle Delays**: All wallpaper state toggles, glass/solid transitions, and reload daemons (`wallpaper.sh`, `ensure_awww.sh`, `watcher.sh`) must enforce serialization with a **minimum 1.5-second settle separation**.
- Rapid visual transition loops must never be executed on the live compositor.

## Related Nodes
- [[Hyprland Architecture]]
- [[Lockscreen Testing Prohibition]]
- [[QML Scene-Graph Coordinate Gating]]
