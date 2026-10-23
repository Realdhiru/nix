---
name: NixOS / Hyprland Rice & Configuration
description: High-density operational reference for maintaining the user's NixOS desktop, Hyprland rice, and QuickShell widgets.
---

# NixOS / Hyprland Rice & Configuration

## 1. Operating Rules & Core Reference

All global architecture pillars, hardware authority (ASUS Vivobook S 15 OLED K5504VA), multi-doc sync invariants (`README`, `CHANGELOG`, `decisions.md`, `tacit_knowledge.md`), notification brevity rules, and verification discipline are canonically defined in [~/nix/AGENTS.md](file:///home/realdhiru/nix/AGENTS.md) and apply unconditionally.

### Technical Rice & Subsystem Invariants:
9. **Cached-Widget Lifecycle, Clipboard, Tray & Battery Invariants**:
    - `Main.qml` sets cached `targetObj.visible = true` once and never resets it: `onVisibleChanged` fires exactly once per process. Per-open refresh/state-reset belongs in `showWidget()` (invoked on every open). `Shortcut{enabled: window.visible}` and `running: window.visible` animations otherwise stay armed forever.
    - Clipboard paste must declare MIME (`wl-copy --type image/png` / `--type text/plain;charset=utf-8`); bare `wl-copy` offers text only. Serialize copy→close (one `Process` + `onExited`), never racing `execDetached` pairs. `wl-paste --watch cliphist store` pairs live in supervised systemd user units (`Restart=always`), never unsupervised `exec_cmd` one-shots.
    - Battery runtime comes only from `Quickshell.Services.UPower` (`UPower.displayDevice`: `energy`, `energyCapacity`, `changeRate`, `timeToFull`). Never `FileView`/timer-poll sysfs (zero inotify). `isLaptopBattery` matches both `DisplayDevice` and `BAT0` — source from `displayDevice` directly.
    - SNI tray: clients register once at startup and never re-announce (a watcher restart empties the tray until clients restart). `kdeconnectd` exports no `StatusNotifierItem` — the icon requires `kdeconnect-indicator`. `blueman-applet` (GtkStatusIcon) cannot provide SNI icons. Never denylist `kdeconnect` while the indicator is autostarted. EasyEffects is decommissioned in favor of native PipeWire `filter-chain`.
    - Media telemetry lives only in root `MusicState.qml` (pragma Singleton); `TopBar.qml`/`SideBar.qml` alias it and must never own `playerctl --follow`, `music_info.sh`, json `FileView`, `cava`, or media timers. UI files are never merged for backend sharing.
    - Marker-file `FileView`s (`wallpaper_killed`, `gaming_mode`) require `onFileChanged: { reload(); updateSolidMode(); }` — directory-watch signals create/delete but the buffer stays stale otherwise. Never SIGHUP a terminal to reload config; `touch` the config files (wezterm hot-reloads on mtime).
    - Coffee state lives only in `SysData.coffeeActive` (+ `setCoffee()`); volume writes go only through `wpctl` (Pipewire is read-only for display). Every persistent QML `Process` stops itself in `Component.onDestruction` — engine reloads orphan children otherwise.
    - Battery direction comes only from `UPower.onBattery`, never `timeToFull` (0 when unestimable → discharge math while charging). Verify non-ASCII literals with `hexdump` after editing — they drop silently to `""`.
    - Mode indicators integrate into a host pill (coffee inside battery, on only while active) — never inside shared trays. Sidebar has no music UI (TopBar + MusicState own it). Visibility toggles require 3+ modifiers (plain binds can't require both Alts). Cold-start sync uses backend change signals, never deferred timers. Boot-critical `FileView`s use `blockLoading: true`.
    - Bar position switches sequence (incoming reserves first, outgoing releases after grace). Every runtime-flag `FileView` pairs `watchChanges` with `onFileChanged: reload()`. Substitute every template placeholder in every theme mode. Byte-patch non-ASCII glyphs + hexdump-verify.
    - Unconfirmed session locks quit loudly within 5s (never idle invisible). Lock spawn is single-flight; strays (alive + session unlocked + >45s) are reaped; lock-state matches binaries only, never cmdline mentions.
    - Never position layout against animating geometry (no anchor offsets bound to `childrenRect`/implicitHeight — fights tweens, causes jitter). `qs_manager.sh` brutal paths reap only PPID-1 follower strays (exact full-command patterns; never bare names, never clipboard owners).

## 2. Invariant Hardware & Architecture Policies

- **Power Authority**: TLP 1.9.1 is the sole hardware authority (`power.nix`). `asusd` only enforces the 80% charge ceiling (`charge_control_end_threshold = 80`). `asusd.ron` must keep `bat_profile = Balanced` and `change_platform_profile_on_battery = false` to prevent hardware throttling on battery.
- **Lid Policy**: `HandleLidSwitch = "ignore"`. Laptop lid closure never triggers unannounced suspend. Suspend is manual (`Shift + Esc`) or automated via 30-minute idle sleep.
- **Balanced Battery Profile**: `balance_performance`, Turbo `1`, Platform Profile `balanced`, ASPM `powersupersave` is empirically locked.
- **Automated AC/Battery Profile Switching**: Unplugging AC power must unconditionally switch hardware power profile to `balanced` (invoking `power.sh profile balanced` -> TLP, ACPI `/sys/firmware/acpi/platform_profile`, and `asusctl`) and clear `_manualOverride = false` in `SysData.qml`. Startup reconciliation must never restore a cached `performance` profile while running on battery.
- **Coffee Mode & Persistent Idle Inhibition**:
  - `SUPER + CTRL + U` invokes `power.sh inhibit` to acquire `systemd-inhibit --what=idle:sleep --who=idle-inhibit-toggle --why="Coffee mode (idle inhibit)" --mode=block sleep infinity`.
  - State is canonically persisted in `~/.cache/quickshell/state.json` under `modes.coffee`.
  - `restore_state.sh` checks `modes.coffee` and automatically re-engages the systemd inhibitor on QuickShell reloads, Hyprland restarts, and cold boots until explicitly toggled off.
  - In `hypridle.conf`, idle timers enforce DPMS off at 120s, lock at 150s, and suspend at 1800s (30m) with `ignore_dbus_inhibit = false` and `ignore_systemd_inhibit = false`.
- **QuickShell IPC & Event-Driven Architecture**:
  - Native C++ event-driven bindings only (`Quickshell.Hyprland`, `Quickshell.Services.Pipewire`, `FileWatcher`, `FileView { watchChanges: true }`). Never fork bash polling loops or subprocess chains inside QML.
  - Sizing in popups must use `currentWidth: Screen.width` (single-pass reference). Never pass device-pixel bounds (`Config.masterWidth`) to popup `Scaler` instances to prevent double-scaling clipping.
  - Workspace bar modules (`SideBar.qml`, `TopBar.qml`) must debounce multi-event IPC bursts via a 16ms single-flight timer (`wsDebounceTimer`) and decouple layout centering offsets from animating delegate sizes to prevent frame-to-frame coordinate fighting and highlight indicator stutter.
  - **Scene-Visibility Gating for Positioning**: All `ListView.positionViewAtIndex()` and carousel settle passes must be strictly gated on `window.visible && view.width > 0`. Offscreen preloading (`visible: false`) creates unmapped scene graph nodes where coordinate math resolves to 0, causing negative clamp glitches on frame 0.
- **Out-of-Store Symlinks**: Home Manager `mkOutOfStoreSymlink` targets live `~/nix/dotfiles/` for instant zero-rebuild live updates.
- **Hardware Quirks**:
  - Machine-specific hardware quirks isolated in `hosts/<host>/hardware/` (e.g. `hosts/nixos/hardware/asus.nix`).
  - ASUS OLED brightness keys: rebound after hybrid-sleep in `hosts/nixos/hardware/asus.nix`.
  - WirePlumber & Audio Priorities: `50-disable-libcamera.conf` disables libcamera to avoid UVC stream collision. `51-device-autoswitch.conf` disables `bluetooth.autoswitch-to-headset-profile` (preventing AVDTP live-renegotiation crashes on TWS earbuds) and gives external physical outputs priority 2150.
  - Native PipeWire Equalizer & Handover: Virtual 10-band equalizer filter chain (`effect_input.eq10`) sits at priority 2200, guaranteeing audio apps process through the EQ while its passive output routes deterministically to external sinks (2150) or internal speakers (1000).
  - Multi-Output Audio Broadcast: `Super + Ctrl + V` (`toggle_multi_sink.sh`) dynamically broadcasts the equalizer output across all connected external endpoints simultaneously via sub-2ms `pw-link` graph links.
  - WebRTC Microphone Cleaning: `60-echo-cancel.conf` binds `libpipewire-module-echo-cancel` to internal stereo array `HiFi__Mic2__source`, cancels speaker acoustic bleed against `effect_input.eq10:monitor`, and publishes `echo_cancel_source` at priority 2100 with zero daemon overhead.
  - Web Apps Hardware Video Acceleration: All Brave web apps and browser windows must receive native VA-API zero-copy hardware acceleration via `~/.local/bin/brave` (`--use-gl=angle --use-angle=gl --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations --enable-zero-copy`). Video apps (YouTube) must remain 100% solid opacity (`1.0`) with `idle_inhibit = "focus"`. WhatsApp must never have translucent glass opacity.

## 3. Workflow & Verification Commands

```bash
# Lint QML widgets
nix build ~/nix#checks.x86_64-linux.qml-lint

# Rebuild NixOS with health gate
rebuild "<commit message>"

# Dry-run configuration
sudo nixos-rebuild dry-run --flake ~/nix#nixos

# Non-destructive Hyprland/QuickShell reload
~/.config/hypr/scripts/reload.sh

# Authoritative QuickShell reload
~/nix/dotfiles/hypr/scripts/qs_manager.sh reload

# Audio subsystem recovery
~/.config/hypr/scripts/fix_audio.sh

# Coffee mode query / toggle
~/.config/hypr/scripts/power.sh inhibit status
~/.config/hypr/scripts/power.sh inhibit toggle

# Fuzzel picker testing (app, file, emoji, glyph)
~/.config/hypr/scripts/fuzzel_menu.sh emoji
~/.config/hypr/scripts/fuzzel_menu.sh glyph
```

## Wine/Proton storage janitor (gameclean)
gameclean — packaged in pkgs/gameclean.nix (docs/gameclean.md). Wine games scatter files across 5 locations (game dir, Wine prefixes, umu prefix caches, ~/.cache, Lutris ymls); run `gameclean` (preview) after any game uninstall or failed install, `gameclean -y` only after reading the preview. Working Lutris-referenced titles are never flagged.
