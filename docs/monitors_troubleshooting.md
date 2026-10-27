# External Monitor & Multi-Display Runbook & Diagnostics

This document is the authoritative diagnostic and operational manual for testing, configuring, and troubleshooting external monitors, docking stations, display mirroring, and per-output wallpapers on this NixOS / Hyprland system.

---

## 1. System Display Architecture & Core Principles

1. **Hardware Authority & Base Display**:
   - Machine: **ASUS Vivobook S 15 OLED (K5504VA / S5504VA)**.
   - Internal Panel: `eDP-1` (2880x1620 @ 120Hz, 16:9, Samsung Display Corp. `0x4180`, 10-bit color, scale `2.0`).
   - DRM / KMS: Intel Iris Xe Graphics (`i915` driver, Aquamarine Wayland DRM backend). Supports up to 4 concurrent hardware display pipes/CRTCs.

2. **Universal Catch-All Rule**:
   - Declared in [`dotfiles/hypr/hyprland.lua`](file:///home/realdhiru/nix/dotfiles/hypr/hyprland.lua):
     ```lua
     hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
     ```
   - Any connected display (HDMI, USB-C DP Alt Mode, DisplayPort hub) immediately works out-of-the-box without hardcoded connector names or manual geometry configuration.

3. **Hardware Override Separation**:
   - Machine-specific physical panel descriptors live in per-host Nix configuration:
     - [`home.nix`](file:///home/realdhiru/nix/home.nix) generates `~/.config/hypr-local/monitors.lua`.
     - Loaded safely via protected `pcall` in `hyprland.lua`. Universal dotfiles remain 100% portable across hardware.

4. **Dynamic Layout Intent Management**:
   - Persisted in `${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}/monitors/intent.json` (`{"layout": "extend"|"mirror", "displays": { ... }}`).
   - `apply_layout(explicit_intent)` evaluates the intent dynamically:
     - Identifies the internal panel via prefix check: `is_internal_monitor(name)` matches `eDP`, `LVDS`, `DSI`, `MIPI`.
     - In **Mirror Mode**: external displays mirror the internal display (`hl.monitor({ output = m.name, mirror = internal.name })`).
     - In **Extend Mode**: external displays are un-mirrored with `mirror = ""` and positioned beside the internal panel using saved custom scale/placement if present.
     - Headless / Desktop systems without an internal panel cleanly fallback to extend mode without arbitrary source selection.

5. **Per-Output Wallpaper Routing**:
   - Managed via Home Manager systemd user units:
     - `awww-daemon.service`: Wayland wallpaper daemon listening on `$XDG_RUNTIME_DIR/wayland-1-awww-daemon.sock`, launched with `--no-cache --format argb` to avoid raw frame caching bloat.
     - `mpvpaper@<out>.service`: Per-output templated video wallpaper unit consuming `%h/.local/state/mpvpaper/%i.env` with `%i` (verbatim connector name, preserving dashes).
   - `set.sh` resolves all outputs upfront (`OUT_JOINED`) and guarantees `--outputs "$OUT_JOINED"` is passed to `awww img` along with `--filter Nearest` (GIFs) and `--filter Bilinear` (images), preventing disconnected cache scans and Lanczos3 stalls.
   - `WallpaperPicker.qml` inspects active wallpapers via native `awww query --json` (zero regex scraping) and dispatches commands with `-o <out>`.

---

## 2. Fast Triage & Diagnostic Commands

When an external monitor does not display, stutters, misaligns, or shows the wrong wallpaper, run these read-only checks first:

### Step 1: Check Wayland Output Recognition & Mirror State
```bash
hyprctl monitors all -j | jq -r '.[] | {name: .name, description: .description, width: .width, height: .height, scale: .scale, refreshRate: .refreshRate, mirrorOf: .mirrorOf, disabled: .disabled, x: .x, y: .y}'
```
- **What to look for**:
  - `disabled`: Ensure output is `false`.
  - `mirrorOf`: `"none"` for extended displays; `"0"` or primary monitor ID for mirrored displays.
  - `scale`: External 1080p/1440p displays usually require `1.0`, while 4K displays may require `1.5` or `2.0`.

### Step 2: Check Kernel DRM Connectors & Hotplug State
```bash
for conn in /sys/class/drm/card*-*; do
    if [ -f "$conn/status" ]; then
        echo "$(basename "$conn"): status=$(cat "$conn/status"), enabled=$(cat "$conn/enabled" 2>/dev/null || echo 'N/A')"
    fi
done
```
- **What to look for**:
  - If `status=connected` but not in `hyprctl monitors`, Hyprland has not initialized the output or modesetting failed.

### Step 3: Check Display Layout Intent
```bash
cat "${DESKTOP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/desktop}/monitors/intent.json"
```
- Should output JSON containing `"layout": "extend"` or `"mirror"` and display preferences.

### Step 4: Check Active Wallpaper State per Monitor
```bash
awww query --json | jq .
```
- Inspect whether `awww` recognizes all outputs and has loaded active image buffers.

### Step 5: Check Video Wallpaper Services (if applicable)
```bash
systemctl --user status "mpvpaper@*" --no-pager
```

---

## 3. Synthetic Testing Protocol (Zero Cable Required)

To verify multi-monitor hotplugging, docking, mirroring, and un-mirroring without physical monitors:

```bash
# 1. Create virtual displays
hyprctl output create headless DP-1
hyprctl output create headless HDMI-A-1

# 2. Test Mirroring
hyprctl eval "apply_layout('mirror')"
hyprctl monitors all -j | jq -c '.[] | {name: .name, mirrorOf: .mirrorOf}'

# 3. Test Extending & Un-mirroring
hyprctl eval "apply_layout('extend')"
hyprctl monitors all -j | jq -c '.[] | {name: .name, mirrorOf: .mirrorOf, x: .x, y: .y}'

# 4. Cleanup virtual displays
hyprctl eval 'hl.monitor({ output = "DP-1", mirror = "" }); hl.monitor({ output = "HDMI-A-1", mirror = "" })'
hyprctl output remove DP-1
hyprctl output remove HDMI-A-1
```

---

## 4. Known Pitfalls, Traps & Architecture Constraints

1. **Hyprland Lua Monitor Mirroring Traps**:
   - **Subordinated Monitors Disappear from Active List**: When an output is mirrored via `hl.monitor({ output = "DP-1", mirror = "eDP-1" })`, it drops from `hl.get_monitors()` and `hl.get_monitor("DP-1")` returns `nil`. It is only visible in `hyprctl monitors all` or internal compositor lists.
   - **Un-mirroring Protocol**: To revert a mirrored output back to an independent screen in Lua, you **must** supply `mirror = ""` in `hl.monitor({ output = name, mirror = "" })`. Simply setting `mode` and `position` will keep the mirror binding active.
   - **Mode "disable" vs Boolean disabled**: `hl.monitor({ output = name, mode = "disable" })` will fail with `hl.monitor: error applying field 'mode'`. Always use `hl.monitor({ output = name, disabled = true })`.

2. **Intel GPU DRM Ring Buffer Limit**:
   - Rapid back-to-back monitor layout changes or wallpaper switches within milliseconds saturate the Intel GPU `rcs0` ring buffer, triggering an Aquamarine DRM page-flip crash (`CHyprOpenGLImpl::begin` assertion failure $\rightarrow$ `SIGABRT` $\rightarrow$ Safe Mode).
   - Always allow **1.5s separation** between successive layout switches.

3. **External Port & Cable Bandwidth Limitations**:
   - The laptop's HDMI port and Thunderbolt/USB-C DP Alt Mode share Intel Iris Xe display bandwidth.
   - Driving 4K @ 120Hz or multiple high-refresh displays concurrently may exceed HDMI 2.0 / DP 1.4 link rates, causing displays to fall back to 30Hz or drop sync. When troubleshooting flicker, test with `preferred` or 60Hz.
