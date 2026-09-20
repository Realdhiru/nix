# Historical Debugging & Troubleshooting Knowledge Base

A chronological, categorized index of all system and rice issues resolved in this repository, their root causes, and exact architectural solutions.

---

## 1. Display, Monitors & Compositor

### ASUS OLED Brightness Fn Keys Unresponsive Post-Hibernate
- **Symptom:** After critical-battery hybrid-sleep or resume, Fn brightness keys stop delivering ACPI events to Hyprland.
- **Root Cause:** Kernel auxiliary video bus driver (`acpi.video_bus.0`) stalls ACPI notifications across low-power transitions.
- **Solution:** Rebind the driver via systemd hook in [`hosts/nixos/hardware/asus.nix`](file:///home/realdhiru/nix/hosts/nixos/hardware/asus.nix):
  `echo acpi.video_bus.0 > /sys/bus/auxiliary/drivers/video/unbind` followed by `bind`.

### Intel Iris Xe KMS Mode-Switch Delay & OEM Splash Double-Flash
- **Symptom:** Flickering mode-switch delay between UEFI boot and login manager; ASUS OEM splash renders twice.
- **Root Cause:** Late modesetting inside stage 2 userspace, and kernel re-rendering ACPI BGRT bitmap during handover.
- **Solution:** In [`hosts/nixos/default.nix`](file:///home/realdhiru/nix/hosts/nixos/default.nix) & [`modules/system/boot.nix`](file:///home/realdhiru/nix/modules/system/boot.nix):
  - Add `i915` to `boot.initrd.kernelModules` for early KMS in stage 1 initrd.
  - Pass `i915.fastboot=1`, `bgrt_disable`, `video=efifb:nobgrt`, and `fbcon=nodefer` to suppress double splash rendering.

### Ly Display Manager Crash & Stale Session Logs
- **Symptom:** Display manager held by network units; unmanaged `~/ly-session.log` created in `$HOME`.
- **Root Cause:** Default `display-manager.service` was serialized behind `network.target`; legacy Ly session log setting defaulted to creating a local file.
- **Solution:** In [`modules/system/services.nix`](file:///home/realdhiru/nix/modules/system/services.nix):
  - Decoupled `systemd-user-sessions` to only wait on `remote-fs.target` and `nss-user-lookup.target`.
  - Set `services.displayManager.ly.settings.session_log = null;` to defer all logging to `journalctl`.

---

## 2. Audio & Media

### MPV Local Media MPRIS Signals Missing
- **Symptom:** Local media played in `mpv` failed to appear in TopBar and Music popup.
- **Root Cause:** `mpv` requires `mpvScripts.mpris` plugin; static out-of-store symlinks in `~/.config/mpv/scripts/` break when old Nix store paths are garbage-collected.
- **Solution:** Added declarative symlink in [`home.nix`](file:///home/realdhiru/nix/home.nix):
  `xdg.configFile."mpv/scripts/mpris.so".source = "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";`.

### EasyEffects Daemon Lifecycle & Preset Handoff
- **Symptom:** Spawning EasyEffects inside scripts caused daemon exits or duplicated processes.
- **Root Cause:** EasyEffects presets live in `~/.local/share/easyeffects/output` (not `~/.config`); daemon must be single-instance.
- **Solution:** Managed via Home Manager `services.easyeffects.enable = true;`. Scripts only trigger `easyeffects --load-preset <preset>` via D-Bus handoff.

---

## 3. Power, Battery & Thermals

### High Battery Power Draw (~18W) & CPU Frequency Spikes
- **Symptom:** Excessive battery drain and fan noise during light idle workloads.
- **Root Cause:** ASUS platform profile and energy performance preference (EPP) were fighting; CPU governor was pinned to performance.
- **Solution:** In [`modules/system/power.nix`](file:///home/realdhiru/nix/modules/system/power.nix):
  - TLP 1.9.1 established as sole hardware authority; `asusd` restricted to 80% charge threshold.
  - Locked Balanced profile: `CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power"`, `CPU_BOOST_ON_BAT = 0`, `PLATFORM_PROFILE_ON_BAT = "balanced"`, `PCIE_ASPM_ON_BAT = "powersupersave"`.
  - Enabled Intel framebuffer compression: `boot.kernelParams = [ "i915.enable_fbc=1" ]` (saves ~2.2 GB/s memory bandwidth on 2.8K 120Hz OLED).

### EPP Writes Refused (EBUSY)
- **Symptom:** Manual writes to `/sys/devices/system/cpu/cpu*/power/energy_perf_bias` failed with `Device or resource busy`.
- **Root Cause:** Intel P-State driver refuses EPP adjustments while CPU governor is set to `performance`.
- **Solution:** `set_epp.sh` helper sets `scaling_governor = powersave` immediately prior to applying EPP values.

### Focus Daemon Battery Wakeups
- **Symptom:** Battery discharge interrupted every second.
- **Root Cause:** `focus_daemon.py` was calling `pgrep -x hyprlock` inside its 1-second main loop (3,600 fork/exec calls per hour).
- **Solution:** Replaced external shell call with direct zero-fork in-process IPC query against hyprland socket.

---

## 4. Hardware Quirks & WebCam

### Sonix FHD Webcam (3277:0022) USB Babble & Disconnects
- **Symptom:** Webcam disconnected with `ioctl(VIDIOC_DQBUF): Invalid argument` / `No such device` during WebRTC browser calls.
- **Root Cause:** Firmware bug crashes controller when non-native resolution or MJPEG compression is requested; simultaneous `libcamera` and `v4l2` monitors caused competing initialization.
- **Solution:** In [`hosts/nixos/hardware/sonix-webcam.nix`](file:///home/realdhiru/nix/hosts/nixos/hardware/sonix-webcam.nix) and [`home.nix`](file:///home/realdhiru/nix/home.nix):
  - Created `v4l2loopback` virtual device `/dev/video10` fed by an on-demand FFmpeg loopback streaming native 1080p YUYV pass-through.
  - Disabled conflicting WirePlumber `libcamera` monitor via `wireplumber.conf.d/50-disable-libcamera.conf`.
  - Disabled USB autosuspend for device (`3277:0022`) in TLP.

### Single-Radio Wi-Fi Roaming vs AP Concurrency
- **Symptom:** Investigated simultaneous Wi-Fi client (STA) and Hotspot (AP) repeating on campus network (`KIET`).
- **Root Cause:** `iw list` confirms `#channels <= 1`. Adapter hardware has only one frequency synthesizer; dynamic 5 GHz DFS roaming drops virtual AP beacons whenever upstream AP steers channels.
- **Solution:** Retained native NetworkManager hotspot architecture to share Ethernet/USB tethering over Wi-Fi, restoring client connection within 1s of hotspot shutdown.

---

## 5. QuickShell & Desktop Widgets

### Double-Scaling Clipping in Popups
- **Symptom:** Popups clipped content off-screen on HiDPI displays.
- **Root Cause:** Passing `Config.masterWidth` to popup `Scaler` caused multiplication (`1.33x * 1.33x = 1.77x`).
- **Solution:** All popup `Scaler` instances must bind `currentWidth: Screen.width` (single-pass reference).

### Ghost Workspaces Visible After Windows Closed
- **Symptom:** TopBar workspaces remained rendered after windows were moved or killed.
- **Root Cause:** Cached JSON snapshot contained `windows > 0` before QuickShell C++ ObjectModel settled.
- **Solution:** Switched to live `Hyprland.toplevels` and `ws.toplevels.count` evaluation wrapped in `Qt.callLater`.

### Screen Blinking During Hyprland Config Reload
- **Symptom:** Running `reload.sh` killed QuickShell processes and caused desktop black flash.
- **Root Cause:** Destructive `pkill -f Shell.qml` unmapped Wayland surfaces.
- **Solution:** Removed destructive pkill from standard reloads; QuickShell remains resident across `hyprctl reload`.

---

## 6. System Safety & Packaging

### i915 GPU Hang Rollback Architecture
- **Symptom:** Bad system updates could cause silent compositor GPU hangs, stranding the session.
- **Solution:** All rebuilds route through [`modules/home/shell.nix`](file:///home/realdhiru/nix/modules/home/shell.nix) `rebuild()`:
  - Automates git commit and records previous known-good generation.
  - Gated switch: executes [`scripts/health-check.sh`](file:///home/realdhiru/nix/scripts/health-check.sh) (checks Hyprland alive + isolated WezTerm GPU-hang probe).
  - Auto-rolls back to prior generation on failure, keeping failed generation in bootloader for debugging.

### Standalone AppImage Execution on NixOS
- **Symptom:** Running `.AppImage` files failed with `No such file or directory` (hardcoded `/lib64/ld-linux-x86-64.so.2`).
- **Solution:** Enabled `programs.appimage.enable = true;` and `programs.appimage.binfmt = true;` in [`modules/system/packages.nix`](file:///home/realdhiru/nix/modules/system/packages.nix).
