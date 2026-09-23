# Architecture Decision Records (ADR)

Concise, permanent architectural invariants and technical rationale. Do not duplicate daily commit logs here (use `CHANGELOG.md`).

---

### 1. User & Credential Parameterization (`user.nix`)
- **Decision:** [`user.nix`](file:///home/realdhiru/nix/user.nix) is the single source of truth for `username`, `name`, and `hostname`.
- **Rationale:** Banished hardcoded `/home/username` across Nix modules, Lua scripts, and Matugen configs for portability. All modules consume `user.username`.

### 2. Power Management & Hardware Authority
- **Decision:** TLP 1.9.1 is the sole hardware authority for platform profiles, EPP, and ASPM.
- **Rules:**
  - `asusd.service` is enabled strictly for 80% battery ceiling enforcement (`charge_control_end_threshold = 80`). `change_platform_profile_on_battery/on_ac` must remain `false`.
  - Lid switch never suspends (`HandleLidSwitch = "ignore"`). Suspend is manual (`Shift + Esc`).
  - `apply_profile.sh` never calls `tlp ac/bat`; ASUS udev rule is sole AC/BAT authority.
  - EPP writes require governor to be set first (`set_epp.sh`).
  - Balanced battery profile (`balance_performance`, Turbo `1`, Platform Profile `balanced`, ASPM `powersupersave`) is empirically locked.

### 3. QuickShell Architecture & IPC
- **Decision:** Native C++ event-driven bindings only (`Quickshell.Hyprland`, `Quickshell.Services.Pipewire`, `FileWatcher`).
- **Rationale:** No periodic bash polling loops in QML. Delivers 6ms workspace and 8ms volume response times with zero idle CPU overhead.
- **Rules:**
  - `Scaler` in popups must use `currentWidth: Screen.width` (single-pass). Never pass device-pixel bounds (`Config.masterWidth`) to prevent double-scaling clipping.
  - Music geometry derives from `timeText.implicitWidth` minimum bounds; long titles marquee scroll.
  - Lockscreen live wallpaper draws inside `Lock.qml` via `WlSessionLock`.

### 4. Hardware Quirks Modularization (`hosts/nixos/hardware/`)
- **ASUS Vivobook OLED (`asus.nix`):**
  - Brightness Fn keys drop ACPI events after hybrid-sleep. Fixed via `systemd-hybrid-sleep` post-hook unbinding and rebinding `acpi.video_bus.0`.
- **Sonix FHD Webcam (`sonix-webcam.nix`):**
  - USB controller babble crash on MJPEG/non-native resolutions. Fixed via `v4l2loopback` `/dev/video10` pass-through feeder (`camera-loopback.sh`) streaming native YUYV.
  - Conflicting `libcamera` monitor disabled in WirePlumber (`50-disable-libcamera.conf`).

### 5. Rebuild Safety Pipeline (`modules/home/shell.nix`, `scripts/health-check.sh`)
- **Decision:** All system switches must route through `rebuild()`.
- **Rationale:** Pre-records previous generation, stages/commits, performs health-gated validation (Hyprland alive + isolated WezTerm GPU-hang probe), and executes automated rollback if critical checks fail. Bad generations are kept bootable in bootloader.

### 6. Declarative Symlinks & Theming
- **Decision:** Out-of-store symlinks (`mkOutOfStoreSymlink`) for `dotfiles/` to enable instant live reloading without rebuilds.
- **Decision:** Decoupled **Wallust** theme engine (`dotfiles/wallust/`) using Lch colorspace and 16 ANSI color extraction. Completely replaces Matugen. Emits all dynamic palette outputs to `~/.cache/theme/` (QuickShell, WezTerm 16-color ANSI, Cava, GTK, Qt).
- **Rule:** Wallust engine must remain strictly self-contained and portable; wallpaper handlers and QuickShell widgets communicate only via clean file contracts (`generate.sh <image>` and `~/.cache/theme/colors.json`).

### 7. Containerized .deb Support (Distrobox + Rootless Podman)
- **Decision:** Rootless Podman daemonless runtime (`virtualisation.podman.enable = true`, `dockerCompat = false`) combined with Distrobox (`deb-box`).
- **Rationale:** Zero background daemons, zero battery/CPU idle drain, and no root escalation vectors. Applications install once and export native `.desktop` files into Fuzzel. When closed, processes exit completely.
- **Rules:** GUI and Electron packages inside Distrobox must enforce native Wayland (`ELECTRON_OZONE_PLATFORM_HINT=auto`, `--ozone-platform-hint=auto`) and include container-side portal fallbacks (`zenity`, `xdg-utils`, Mesa DRI drivers) to avoid Xwayland Glamor shader crashes during file picker navigation.

### 8. Architectural Modularity & Subsystem Decoupling
- **Decision:** Strict modular boundaries across system features. No mixed files or tight cross-dependencies.
- **Subsystem Contracts:**
  - **Theming (`dotfiles/wallust/`)**: Portable standalone color engine. Contains extraction, PIL/Magick luminance math, template generation, neutral fallback mode (`./generate.sh --neutral`), and client reloads. Zero wallpaper or UI dependencies.
  - **Wallpaper (`dotfiles/wallpaper/`)**: Portable desktop background manager (`wallpaper.sh`). Encapsulates daemon lifecycles (`awww`, `mpvpaper`), fast thumbnail generation, directory inotify watching, and online DuckDuckGo search. Hands off to theme engine via clean one-line async execution (`$THEME_ENGINE "$WALLPAPER" &`).
  - **QuickShell Widgets**: QuickShell components (e.g. `wallpaper/`, `network/`, `music/`, `calendar/`) must remain self-contained with localized `Scaler.qml` and `Theme` adapters, eliminating `import "../"` parent breakages when copied to other QuickShell environments.

