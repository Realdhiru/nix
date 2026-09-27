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
- **Decision:** Native C++ event-driven bindings only (`Quickshell.Hyprland`, `Quickshell.Services.Pipewire`, `FileView { watchChanges: true }`, `FileWatcher`).
- **Rationale:** No periodic bash polling loops or subprocess chains in QML. Eliminates fork storms, process starvation, and CPU wakeups, delivering instantaneous frame-0 startup and zero idle CPU overhead.
- **Rules:**
  - Never fork bash `Process` to read files or watch file state (`colors_wait.sh`, `settings_wait.sh`, `solidModeDetector`). Use native `Quickshell.Io.FileView`.
  - In QuickShell C++, `FileView` maintains an internal text buffer; any `onFileChanged` handler must explicitly call `fileView.reload()` to refresh `text()`.
  - Layer surface dismissals must be two-phase: keep `visible = true` while running exit transitions (130ms fade/scale), setting `visible = false` only when opacity reaches 0. Never unmap the layer surface on frame 0.
  - QuickShell widgets must remain in separate modular files. Lazy QML compilation ensures inactive widgets consume zero CPU cycles, RAM, or timers.
  - Layer blur rules in `rules.lua` must match all QuickShell namespaces (`namespace = "^(quickshell|qs-.*)$"`) with `ignore_alpha = 0.05` to guarantee hardware Kawase blur behind every surface.
  - Frosted glass cards and floating control bars must use `root.base` at `Config.effectivePopupOpacity` backed by a subtle anti-bleed base layer (`crust` at 0.16–0.18) and specular reflection highlight. Never stack high-opacity (>0.80) solid crust fills that drown out compositor blur.
  - **Global Consistency & Mandatory Confirmation Rule**:
    - **Scope**: Applies to ANY visual/theme change across the entire system (QuickShell widgets, Fuzzel, hyprlock, topbar, window borders, `rules.lua` layer rules, etc.).
    - **No Local Overrides**: Visual properties (opacity, blur, tokens, borders, radius, spacing) must be applied across every widget/app sharing that visual category in a single pass using shared tokens.
    - **Mandatory Pre-Change Check-In**: Before executing any UI/look/theme change, the agent must pause, present the proposed changes and scope, and await explicit user confirmation before modifying files.
  - `Scaler` in popups must use `currentWidth: Screen.width` (single-pass). Never pass device-pixel bounds (`Config.masterWidth`) to prevent double-scaling clipping.
  - Music geometry derives from `timeText.implicitWidth` minimum bounds; long titles marquee scroll.
  - Lockscreen live wallpaper draws inside `Lock.qml` via `WlSessionLock`. Lockscreen telemetry and media controls must remain 100% zero-polling, bound exclusively via kernel/tmpfs inotify `FileView` watchers (`/sys/class/power_supply/BAT0/`, `music_info.json`).
  - **Theme Singleton Attempt & Constraint**: Attempted `Theme.qml` `pragma Singleton` consolidation on 2026-09-27 — caused system-wide black/undefined color rendering across all widgets simultaneously, root cause suspected to be a load-order race unique to singleton lifecycle (`FileView` not resolved before first property access), not fully diagnosed before reverting. Reverted to per-widget `Theme {}` instantiation, confirmed working. Do not retry without first writing a minimal isolated test case for singleton + `FileView` load-order behavior in QML before touching the real widget suite again.

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
- **Dark Mode Lock Rule:** Global theme defaults permanently to dark mode (`saliencedark16`). Wallpaper switches never trigger automatic light mode. Light mode is strictly manual via `settings.json` (`"themeMode": "light"`).
- **Single Theme Output Root:** `~/.cache/theme/` is the *only* runtime theme output. The legacy `~/.cache/matugen` compat tree has been removed — it had zero live consumers once GTK/Qt, WezTerm, and QuickShell all pointed at `~/.cache/theme`. New theme consumers must read `~/.cache/theme/` directly and must never reintroduce a second compat root.

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

### 9. System Tray Architecture & Frameless Liquid Glass Design
- **Decision:** System Tray moved from TopBar into Battery Popup. Frameless (zero-border) visual standard across QuickShell.
- **Rationale:**
  - Status bar declutter: TopBar remains minimal, preserving space for dynamic workspace pills, CAVA audio visualizer with top-to-bottom vertical gradient, and clock/date.
  - Tray access consolidated: Quick access tray icons live directly alongside system toggles (Hotspot, DND, volume, brightness, power profiles) in BatteryPopup header.
  - Zero-border design: Explicitly removed artificial hairline borders, rotating shape masks, and outer stroke containers across all widget popups (`MusicPopup`, `BatteryPopup`, `CalendarPopup`, `PopupCard`, `MonitorPopup`, `FocusTimePopup`, `NetworkPopup`, `ClipboardManager`). Default `borderWidth = 0` and `borderOpacity = 0.0` in `settings.json`.

### 10. Terminal Dynamic ANSI Extraction & OLED Surface Authority
- **Dynamic Wallpaper-Extracted ANSI Palette (`ansidark16` + `lchansi`):**
  - Configured Wallust with `--colorspace lchansi --palette ansidark16 --check-contrast` in [`dotfiles/wallust/wallust.toml`](file:///home/realdhiru/nix/dotfiles/wallust/wallust.toml) and [`dotfiles/wallust/generate.sh`](file:///home/realdhiru/nix/dotfiles/wallust/generate.sh).
  - All terminal ANSI slots (`color0`-`color15`), foreground, background, and cursor in [`wezterm-colors.lua`](file:///home/realdhiru/nix/dotfiles/wallust/templates/wezterm-colors.lua) are dynamically derived from the wallpaper while preserving standard ANSI hue roles (red, green, blue, etc.), preventing muddy cluster collisions.
- **Physical OLED Pitch-Black Root Compositor Background:**
  - In [`dotfiles/hypr/misc.lua`](file:///home/realdhiru/nix/dotfiles/hypr/misc.lua), `background_color = 0x000000` and `force_default_wallpaper = 0`.
  - When wallpaper daemons are terminated (`wallpaper.sh kill`), Hyprland renders pure `#000000`, turning off OLED pixels completely (0.000 nits, 0 mA draw) instead of illuminating the screen with Hyprland's default `0x111111` gray.
- **Deterministic Neutral Theme Bypass:**
  - In [`dotfiles/wallust/generate.sh`](file:///home/realdhiru/nix/dotfiles/wallust/generate.sh), `--neutral` bypasses Wallust salience clustering and ImageMagick histogram extraction, deterministically generating an OLED pitch-black palette without risk of false olive-green color spikes.

### 11. Bootloader Generation Retention & EFI Partition Protection
- **Decision:** Strict `boot.loader.systemd-boot.configurationLimit = 10` in [`modules/system/boot.nix`](file:///home/realdhiru/nix/modules/system/boot.nix).
- **Rationale:** The physical EFI system partition is 511MB. Without an explicit retention limit, systemd-boot generates kernel/initrd pairs in `/boot/EFI/nixos/` indefinitely. Setting a hard limit of 10 keeps rollback entries safe while guaranteeing `/boot` disk usage remains below 200MB (~40% capacity).

### 12. Host MIME Isolation & Container Application Sanitization
- **Decision:** Permanent declarative browser authority in `home.nix` (`http`, `https`, `text/html` locked to `brave-browser.desktop`) and mandatory sanitization in [`distrobox-install-deb.sh`](file:///home/realdhiru/nix/dotfiles/scripts/distrobox-install-deb.sh).
- **Rationale:** Containerized packages (`.deb` files exported via Distrobox) must never inject or alter system-wide web protocols or office document associations. Exported desktop files are strictly filtered to custom schemas (e.g. `x-scheme-handler/codex`) and desktop databases are resynced immediately.


### 13. OpenCode TUI Theme Derivation (Transparency & Diff Wash)
- **Decision:** OpenCode TUI appearance is governed by two declarative TUI-only plugins in [`dotfiles/opencode/tui-plugins/`](file:///home/realdhiru/nix/dotfiles/opencode/tui-plugins), wired through `tui.json` and `home.nix`. TUI plugins live in a dedicated `tui-plugins` dir and are listed explicitly in `tui.json` because the server-side auto-scan of `opencode/plugin` would try to load them and fail (they export `tui()`, not `server()`).
- **Transparency Rule:** Panel surfaces (`backgroundPanel`, `backgroundElement`, `backgroundMenu`) and `diffContextBg` are forced to alpha `0` so the compositor/wallpaper shows through. `generateSystem` already ships `background` as fully transparent; the plugins exist to extend that to the remaining opaque surfaces.
- **Diff Row Wash Rule:** `diffAddedBg`, `diffRemovedBg`, `diffAddedLineNumberBg`, and `diffRemovedLineNumberBg` are **rebuilt**, not merely alpha-adjusted. Upstream `tint()` returns `RGBA.fromInts(...)` with no alpha channel, so it pre-multiplies the ANSI hue into the terminal background at full opacity; against a desaturated Wallust ramp over a black terminal this yields `rgb(21,21,21)` — an opaque black bar. The wash mixes `theme.text` over `theme.background`, then pulls lightly toward the row's own `diffAdded`/`diffRemoved` hue.
- **Rules:**
  - **No hardcoded colors in theme plugins.** Every component must be read from `api.theme.current` on each pass so a wallpaper change re-derives the appearance automatically. Fixed RGB/hex literals are a defect.
  - **Idempotence is mandatory.** Each derivation pass must report `changed === false` when nothing moved, otherwise the slow guard interval spins the renderer. Compare derived floats with a tolerance rather than exact equality.
  - **Shared-RGBA first-write-wins.** `generateSystem` reuses one RGBA instance across multiple theme keys (e.g. `backgroundPanel` and `diffContextBg` are both `grays[2]`). Any pass that mutates colors must dedupe by object identity and respect first-write-wins ordering.
  - Higher-priority passes (e.g. the diff row wash) must run *before* lower-priority ones (panels) so they win if a future OpenCode release aliases their keys.
  - Gutter/line-number background keys must derive identically to their corresponding row key so no two-tone seam appears.
  - Comments citing upstream OpenCode source must reference **symbolic** names (`tint()`, `generateSystem`), never hard line numbers — those drift on every release.

### 14. Nix Context Delivery (AGENTS.md as Router)
- **Decision:** [`AGENTS.md`](file:///home/realdhiru/nix/AGENTS.md) is an always-loaded **router**, not an archive. It carries only architecture facts an agent needs to navigate plus a pointer table from intent to file.
- **Rationale:** Home-manager and editor tooling inject `AGENTS.md` into every session. Mirroring `README.md`/docs into it wastes context on every request. Detailed docs stay on disk and are read on demand.
- **Rules:**
  - `AGENTS.md` must state flake inputs and the floating-pin policy, the module tree map, the Home Manager single entry point (`home.nix`), the `pkgs/` overlay set, and the `flake check` verification command.
  - Each linked doc gets a one-line "read when…" trigger so the agent knows when loading it pays for itself.
  - `repomix-output.xml` (~1.5MB) must carry an explicit do-not-read instruction.
  - Newly added systemic rules are promoted here only after they are stable; day-to-day change history belongs in `CHANGELOG.md`, architectural rationale in this file.
