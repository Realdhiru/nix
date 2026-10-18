---
title: Hardware Video Acceleration & Web Apps
tags: [media, video, vaapi, gpu, intel, brave, wayland]
---

# Hardware Video Acceleration & Web Apps

On Linux Wayland desktops, video streaming applications (YouTube, Twitch, WhatsApp, embedded browser video) require native hardware acceleration via **VA-API** to prevent frame drops, video tearing, and high CPU usage at 4K 60/120fps.

---

## 1. The Nixpkgs Chromium / Brave Wrapper Trap

On traditional distributions, Chromium-based browsers read user flags directly from `~/.config/brave-flags.conf` or `~/.config/chrome-flags.conf`.

In Nixpkgs, Brave is packaged with a custom shell wrapper (`/run/current-system/sw/bin/brave`) that constructs its CLI invocation using `makeShellWrapper`. This wrapper **does not parse or load `~/.config/brave-flags.conf`**.

As a consequence, flags like `--use-gl=angle` and `VaapiVideoDecodeLinuxGL` are silently ignored when launched from desktop entries or simple commands, forcing the browser into unaccelerated software video decode on Intel Iris Xe.

---

## 2. The Solution: Global Wrapper & Direct Injection

To ensure all present and future web apps run with 100% native hardware acceleration:

1. **Global High-Priority PATH Wrapper** (`~/.local/bin/brave`):
   ```bash
   #!/usr/bin/env bash
   exec /run/current-system/sw/bin/brave \
     --use-gl=angle \
     --use-angle=gl \
     --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations \
     --enable-zero-copy \
     "$@"
   ```
   Because `~/.local/bin` precedes `/run/current-system/sw/bin` in `$PATH`, any keybind, terminal call, or app launcher inherits hardware video acceleration automatically.

2. **Direct Keybinding Flag Injections** (`dotfiles/hypr/keybinds.lua`):
   For high-throughput media apps like YouTube (`Super + Alt + Y`), hardware flags are injected explicitly into the command invocation.

---

## 3. Compositor Rules & Video Presentation

Video players running under translucent glass blur cause the compositor (Hyprland Aquamarine) to re-compute multi-pass blur and surface blend operations at 60–120Hz for every decoded frame, generating micro-stutter:

- **YouTube**: Locked to 100% solid opacity (`opacity = "1.0 override 1.0 override"`) and `idle_inhibit = "focus"` in [`rules.lua`](file:///home/realdhiru/nix/dotfiles/hypr/rules.lua).
- **MPV**: Bound to `idle_inhibit = "focus"`.
- **WhatsApp Web**: Kept at solid opacity per user preference (avoiding camera/video translucency).
- **Text & Productivity Web Apps** (Notion, Claude, ChatGPT, To-Do, Monkeytype): Styled with unified glass translucency (`0.57`).

## Related Nodes
- [[Intel GPU Ring Buffer Trap]]
- [[MPV MPRIS Pipeline]]
- [[Window Rules & Glass Layout]]
