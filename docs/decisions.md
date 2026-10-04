# Architecture Decision Records (ADR)

Concise, permanent architectural invariants and technical rationale. Do not duplicate daily commit logs here (use `CHANGELOG.md`).

---

### 1. User & Credential Parameterization (`user.nix`)
- **Decision:** [`user.nix`](file:///home/realdhiru/nix/user.nix) is the single source of truth for `username`, `name`, and `hostname`.
- **Rationale:** Banished hardcoded `/home/username` across Nix modules, Lua scripts, and Matugen configs for portability. All modules consume `user.username`.

### 2. Power Management & Hardware Authority
- **Decision:** TLP 1.9.1 is the sole hardware authority for platform profiles, EPP, and ASPM.
- **Rules:**
  - `asusd.service` is enabled strictly for 80% battery ceiling enforcement (`charge_control_end_threshold = 80`). `change_platform_profile_on_battery/on_ac` must remain `false`. In `asusd.ron`, `bat_profile` and `platform_profile_on_battery` must remain `Balanced` to prevent unwanted firmware throttling (`Quiet` / EPP `Power`) on battery.
  - Lid switch never suspends (`HandleLidSwitch = "ignore"`). Suspend is manual (`Shift + Esc`).
  - `apply_profile.sh` never calls `tlp ac/bat`; ASUS udev rule is sole AC/BAT authority.
  - EPP writes require governor to be set first (`set_epp.sh`).
  - Balanced battery profile (`balance_performance`, Turbo `1`, Platform Profile `balanced`, ASPM `powersupersave`) is empirically locked.

### 3. QuickShell Architecture & IPC
- **Decision:** Native C++ event-driven bindings only (`Quickshell.Hyprland`, `Quickshell.Services.Pipewire`, `FileView { watchChanges: true }`, `FileWatcher`).
- **Rationale:** No periodic bash polling loops or subprocess chains in QML. Eliminates fork storms, process starvation, and CPU wakeups, delivering instantaneous frame-0 startup and zero idle CPU overhead.
- **Rules:**
  - Never fork bash `Process` to read files or watch file state (`colors_wait.sh`, `settings_wait.sh`, `solidModeDetector`, `battery_wait.sh`, `av_event_stream.sh`). Use native `Quickshell.Io.FileView` on kernel/tmpfs files.
  - **Sysfs Inotify Incompatibility Rule**: `FileView` on `/sys` or `/proc` virtual files (e.g. `BAT0/capacity`, `status`, `actual_brightness`) never fires because sysfs pseudo-files emit zero `inotify` events (`IN_MODIFY`). Use `udevadm monitor` (`--subsystem-match=power_supply`, `--subsystem-match=backlight`), UPower D-Bus, or a slow timer. Never replace a udev-based watcher with a `FileView` on sysfs. Before replacing any watcher, prove the new event source fires by logging timestamps on a real state change.
  - Never loop-respawn one-shot bash processes (`dbus-monitor | grep -m 1`) inside QML. Use persistent streaming daemons (`playerctl --follow`) with `SplitParser` or native D-Bus bindings.
  - Monitor enumeration must use native `Quickshell.screens` instead of shelling out to `hyprctl monitors -j`.
  - Volume and mute monitoring must use native `Quickshell.Services.Pipewire` (`Pipewire.defaultAudioSink.audio`) paired with `PwObjectTracker { objects: Pipewire.nodes.values }` to maintain active live subscriptions to Pipewire daemon node changes, delivering instantaneous updates without subprocesses. Imperative property overrides on volume bindings must never be performed to prevent breaking QML reactive dependency tracking.
  - In QuickShell C++, `FileView` maintains an internal text buffer; any `onFileChanged` handler must explicitly call `fileView.reload()` to refresh `text()`.
  - Layer surface dismissals must be two-phase: keep `visible = true` while running exit transitions (130ms fade/scale), setting `visible = false` only when opacity reaches 0. Never unmap the layer surface on frame 0.
  - QuickShell widgets must remain in separate modular files. Lazy QML compilation ensures inactive widgets consume zero CPU cycles, RAM, or timers.
  - Layer blur rules in `rules.lua` must match all QuickShell namespaces (`namespace = "^(quickshell|qs-.*)$"`) with `ignore_alpha = 0.05` to guarantee hardware Kawase blur behind every surface.
  - Frosted glass cards and floating control bars must use `root.base` at `Config.effectivePopupOpacity` backed by a subtle anti-bleed base layer (`crust` at 0.16–0.18). Never stack high-opacity (>0.80) solid crust fills that drown out compositor blur, and do not add top specular 1px hairlines.
  - **Global Consistency & Mandatory Confirmation Rule**:
    - **Scope**: Applies to ANY visual/theme change across the entire system (QuickShell widgets, Fuzzel, hyprlock, topbar, window borders, `rules.lua` layer rules, etc.).
    - **No Local Overrides**: Visual properties (opacity, blur, tokens, borders, radius, spacing) must be applied across every widget/app sharing that visual category in a single pass using shared tokens.
    - **Mandatory Pre-Change Check-In**: Before executing any UI/look/theme change, the agent must pause, present the proposed changes and scope, and await explicit user confirmation before modifying files.
  - `Scaler` in popups must use `currentWidth: Screen.width` (single-pass). Never pass device-pixel bounds (`Config.masterWidth`) to prevent double-scaling clipping.
  - **Scene Visibility Gating for Positioning Math**: Any `ListView.positionViewAtIndex()` or layout settle logic in popup components must be strictly gated on `window.visible && view.width > 0`. Offscreen preloading (`visible: false`) creates objects outside the active visual scene graph where coordinate math and view width are unmapped, causing bad clamps on frame 0.
  - **Dynamic HighlightRangeMode for Carousel Popups**: In full-width carousels (`WallpaperPicker`), `highlightRangeMode` must be dynamically gated (`initialFocusSet ? StrictlyEnforceRange : NoHighlightRange`). Static `StrictlyEnforceRange` forces negative `contentX` clamps (`-preferredHighlightBegin`) when mounting or unmounting in `StackView` before delegate items finish layout, causing viewport truncation and horizontal card displacement.
  - Music geometry derives from `timeText.implicitWidth` minimum bounds; long titles marquee scroll.
  - **Single Authority Geometry & Preload Isolation Rule**: All master popup container dimensions (`animW`, `animH`, `animX`, `animY`) are strictly owned and computed by [`Main.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/Main.qml) via `getLayout()`. Individual popup components must NEVER mutate master container properties through internal property change signals (`onTargetMasterWidthChanged`, etc.). When background preloader timers instantiate offscreen widgets, child geometry assignments overwrite the shared container, causing unrelated widgets to shift horizontally and clip borders. All geometry queries must remain read-only and gated on active display mapping.
  - **TopBar Toggle & Isolation**: TopBar visibility is decoupled from QuickShell daemon lifecycle via `Config.topBarVisible` and LayerShell surface unmapping. Toggling TopBar unmaps `barWindow` and releases the exclusive zone (`reserved: 0 0 0 0`) while keeping QuickShell daemon, popups, floating widgets, and polkit agent fully operational.
  - **Decoupled Dual-Bar Architecture (`TopBar.qml` vs `SideBar.qml`)**: The desktop bar architecture is strictly decoupled into two isolated `PanelWindow` components registered in `Shell.qml`:
    - [`TopBar.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/TopBar.qml): Active when `Config.topBarPosition !== "left"`. Contains the user's pristine horizontal layout (workspaces row, CAVA visualizer, marquee title, horizontal clock/date, battery pill). It contains zero ternary vertical layout hacks, keeping the horizontal configuration 100% intact.
    - [`SideBar.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/SideBar.qml): Active when `Config.topBarPosition === "left"`. Implements Serpantinum's 3-zone vertical modular architecture:
        - **Top Zone**: Vertical workspace capsule with smooth gliding `activeHighlight` slider and kanji/numeric indicators, followed by an active window focus indicator with 90° rotated title text.
        - **Center Zone**: Media card (album thumbnail, horizontal marquee moving song title, horizontal moving timeline, perpendicular 8-row CAVA visualizer with left-to-right waves), classic stacked clock/date (hours over minutes with enlarged typography), and weather card.
        - **Bottom Zone**: System tray card (native `SystemTray.items` with `QsMenuAnchor`), vertical System Monitor (CPU, RAM, Temp), quick status indicators (Pipewire Volume, Wifi, Bluetooth), recording indicator, and icon-only battery card with dynamic capacity/charging coloring.
        - **Auto-Hide Architecture**: Built-in hover-driven auto-hide (`barHover` + `hideTimer`), reserving zero exclusive zone and sliding smoothly into view when touching the monitor's 4px left screen edge.
    - **Orientation-Aware Popup Positioning**: [`WindowRegistry.js`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/WindowRegistry.js) resolves layout coordinates based on bar orientation. When `barPos === "left"`, bottom-docked popups (battery, network) anchor to `bottom-left` next to the battery widget, and `music` anchors to `top-left`, eliminating displacement.
    - **Global Window Escape Key Handling**: [`Main.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/Main.qml) uses `Shortcut { sequence: "Escape"; context: Qt.WindowShortcut }` instead of `Keys.onEscapePressed` to guarantee immediate widget closure regardless of which child element holds active keyboard focus.
    - **Wayland LayerShell Keyboard Interactivity**: `WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand` is required on the `qs-master` overlay layer for `Shortcut` and `Keys.onEscapePressed` to receive key events. Without it, Hyprland reports `a: 0` (keyboard interactive = false) and routes all keypresses directly to the focused client window.
    - **ANTI-PATTERN — `requestActivate()` / `forceActiveFocus()` on PanelWindow**: Never call `masterWindow.requestActivate()` or `targetObj.forceActiveFocus()` in `executeSwitch()`. These fight the Wayland compositor for focus, can prevent `delayedClear` from setting `isVisible = false`, and cause the full-screen `qs-master` overlay to stay mapped indefinitely, eating all pointer and keyboard input system-wide. Focus is already handled by `WlrKeyboardFocus.OnDemand` and StackView's `onCurrentItemChanged`.
    - **ANTI-PATTERN — Single-Shot `delayedClear` with `widgetStack.busy`**: Never guard window unmapping (`isVisible = false`) exclusively behind a single-shot timer checking `!widgetStack.busy`. If a transition was ongoing during dismissal, the timer triggered once, bailed, and permanently abandoned `isVisible = true`. Always use a repeating timer that halts only after clearing `isVisible`.
    - **Hyprland-Lua Process Management**: On this system, Hyprland evaluates socket dispatch commands via Lua (`hl.dispatch(...)`). Standard `hyprctl dispatch exec ...` throws Lua syntax errors. Commands dispatched from shell scripts must format as `hyprctl eval "hl.dispatch(hl.dsp.exec_cmd('...'))"`.
    - **ANTI-PATTERN — `Qt.ApplicationShortcut` in LayerShell**: Never use `Qt.ApplicationShortcut` for `Shortcut` in a multi-window QuickShell setup. It captures the key globally across ALL QuickShell windows (SideBar, Floating, Main), causing unintended side effects. Use `Qt.WindowShortcut` scoped to the owning window.
    - **Unscaled Bar Clearance for Popup Positioning**: Margin offsets from static bars (48px) must never be multiplied by `scale` when `scale < 1.0`. Using `s(52, scale)` under-scales to 41px on 1440×810, placing the popup under the bar's input mask. Fixed offsets (`rx = 52`) are used instead.
    - **Popup-Aware Auto-Hide**: `Config.isPopupOpen` (synced from `masterWindow.isWindowActive`) is included in `SideBar.qml`'s `isRevealed` condition so the sidebar stays visible while interacting with popups in auto-hide mode.
    - Toggled instantaneously via `SUPER + ALT + Up` (top) and `SUPER + ALT + Down` (left) without process restarts or widget layout contamination. Auto-hide toggled via `CTRL + MOD + ALT`.
  - Lockscreen live wallpaper draws inside `Lock.qml` via `WlSessionLock`. Lockscreen telemetry and media controls must remain 100% zero-polling, bound exclusively via kernel/tmpfs inotify `FileView` watchers (`/sys/class/power_supply/BAT0/`, `music_info.json`).

### 4. Canonical Persistent State Architecture (`~/.cache/quickshell/state.json`)
- **Decision**: Single canonical JSON file (`~/.cache/quickshell/state.json`) owns all live user toggle states across the system (`sunset`, `modes`, `power`, `ui`).
- **Rules**:
  - [`restore_state.sh`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/restore_state.sh) automatically re-applies active shaders, `hyprsunset` hardware CTMs, Gaming Mode, DND, and power profiles on QuickShell boot/reload via [`Main.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/Main.qml).
  - Toggling off or resetting any feature restores its entry to neutral defaults in `state.json`. No orphaned flag files or stale state files are permitted.
  - **Theme Singleton Attempt & Constraint**: Attempted `Theme.qml` `pragma Singleton` consolidation on 2026-09-27 — caused system-wide black/undefined color rendering across all widgets simultaneously, root cause suspected to be a load-order race unique to singleton lifecycle (`FileView` not resolved before first property access), not fully diagnosed before reverting. Reverted to per-widget `Theme {}` instantiation, confirmed working. Do not retry without first writing a minimal isolated test case for singleton + `FileView` load-order behavior in QML before touching the real widget suite again.
  - **Display & Shader Architecture Split**: `hyprsunset` daemon owns Temperature + Gamma (hardware CTM/gamma LUT). Hyprland's single `decoration:screen_shader` slot owns Saturation + Paper Grain + CRT Curvature together in one unified GLSL file, since Hyprland only supports one active `screen_shader` at a time. These two systems are fully independent.


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

### 14. Nix Context Delivery (AGENTS.md as Router)
- **Decision:** [`AGENTS.md`](file:///home/realdhiru/nix/AGENTS.md) is an always-loaded **router**, not an archive. It carries only architecture facts an agent needs to navigate plus a pointer table from intent to file.
- **Rationale:** Home-manager and editor tooling inject `AGENTS.md` into every session. Mirroring `README.md`/docs into it wastes context on every request. Detailed docs stay on disk and are read on demand.
- **Rules:**
  - `AGENTS.md` must state flake inputs and the floating-pin policy, the module tree map, the Home Manager single entry point (`home.nix`), the `pkgs/` overlay set, and the `flake check` verification command.
  - Each linked doc gets a one-line "read when…" trigger so the agent knows when loading it pays for itself.
  - `repomix-output.xml` (~1.5MB) must carry an explicit do-not-read instruction.
  - Newly added systemic rules are promoted here only after they are stable; day-to-day change history belongs in `CHANGELOG.md`, architectural rationale in this file.

### 15. File Watcher Semantics & Atomic Write Policy (`Quickshell.Io.FileView` vs Raw `inotifywait`)
- **Empirical Finding:** `Quickshell.Io.FileView` watches by **PATH**, not by inode. It automatically re-arms its watcher across atomic `mv` replacements as well as in-place `cat >` writes (`textChanged` and `fileChanged` fire 100% reliably on both write modes).
- **Rule & Standardized Write Pattern:**
  - **QuickShell `FileView` Contracts (`colors.json`, `music_info.json`)**: Use atomic move (`.tmp` -> `mv`). Atomic move is 100% safe for `Quickshell.Io.FileView` path watchers and eliminates partial-read JSON parse errors during concurrent reads.
  - **Raw Bash / External Script Watchers (`inotifywait -e close_write ...`)**: Raw bash scripts using `inotifywait` on a single explicit file target (rather than watching an entire directory) attach to the underlying Linux inode. Executing `mv` replaces the inode, breaking single-file `inotifywait` handles. For legacy single-file script watchers, use in-place writes (`cat > target`).

### 16. Projects Directory Deletion Protection Policy
- **Decision:** Files and directories inside `~/Projects/` are strictly protected from deletion.
- **Rationale:** `~/Projects/` contains user backups, reference repositories, and uncommitted project workspaces. Agents must never issue `rm` or delete operations against `~/Projects/` or any of its subdirectories.

### 17. OLED Typography & Antialiasing Invariants
- **Decision:** On high-DPI OLED panels with non-standard subpixel layouts (Samsung OLED `eDP-1`), LCD RGB subpixel antialiasing produces red/blue chromatic fringing and edge ghosting.
- **Rules:**
  - In WezTerm ([`dotfiles/wezterm.lua`](file:///home/realdhiru/nix/dotfiles/wezterm.lua)), FreeType load and render targets must be set to `"Normal"` to force clean grayscale antialiasing.
  - In QuickShell / Qt Quick widgets ([`TopBar.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/TopBar.qml)), high-contrast text must use `renderType: Text.NativeRendering` to avoid Qt distance-field texture filtering chromatic fringing.

### 18. Wayland Layer-Shell Geometry & Scaling Invariants
- **Decision:** All QuickShell `PanelWindow` overlay surfaces operate strictly in compositor logical coordinates (`1440x810` on `2880x1620` @ scale 2.0).
- **Rules:**
  - Never configure layer surfaces or popup positioning with raw physical pixel bounds (`2880x1620`). Sizing coordinates using physical dimensions places elements past the logical surface boundary, clipping them off-screen.
  - Sizing fallback in `Main.qml` must derive logical screen space from monitor physical dimensions divided by monitor scale (`Math.round(physWidth / scale)`), ensuring frame-0 and settled coordinates are identical with zero pixel displacement.

### 19. QuickShell Light/Dark Glass Theme State Management
- **Decision:** Theme mode is controlled explicitly by the user via keybind (`SUPER + L`) rather than automatic wallpaper luminance classification.
- **Rationale:** Automatic wallpaper luminance detection fails on complex illustrations (e.g. bright artwork with dark accents) and forces unintended theme flips. Persisting `ui.themeMode` in `~/.cache/quickshell/state.json` provides user control across reloads and cold boots.
- **Rules:**
  - `SUPER + L` triggers [`dotfiles/hypr/scripts/quickshell/toggle_theme_mode.sh`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/toggle_theme_mode.sh) to toggle `ui.themeMode` between `"dark"` and `"light"`.
  - `Theme.qml` reads `state.json` via native `FileView` watcher and exposes `isLightMode`.
  - Light mode increases `antiBleedOpacity` to `0.35` and `effectivePopupOpacity` to `0.55` in [`Config.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/Config.qml) to guarantee high visual contrast over light background illustrations.

### 20. Operational Verification Invariants & Anti-Patterns
- **Screenshot Debugging Ban (Token & Latency Discipline):**
  - Capturing full-screen screenshots via `grim` to verify UI states burns excessive context tokens, inflates turnaround latency, and provides zero semantic insight into internal state machines.
  - Verification must rely on deterministic log assertions (`console.log`), direct file inspection via `FileView` / `jq`, and native IPC queries. Screenshots are strictly reserved for user-requested visual design evaluations.
- **Authoritative Process Recovery vs Stale Artifact Reverse-Engineering:**
  - When QuickShell or helper daemons experience lifecycle shifts, dead PID files and abandoned IPC sockets (`/run/user/1000/quickshell/by-id/`) must not be reverse-engineered or polled.
  - Always query the live daemon dynamically (`pgrep -fa quickshell`) or execute an authoritative clean reload via [`reload.sh`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/reload.sh).
- **Responsive Compute over Artificial Throttling:**
  - Power conservation must never degrade interactive responsiveness. Throttling CPU governors (EPP `power` / `quiet`) degrades application launch times (IDE, browser) and induces UI compositing stutter.
  - True mobile efficiency is achieved via rapid race-to-sleep (`balance_performance`, balanced platform profile, hardware ASPM `powersupersave`) paired with automated idle suspension.

### 21. Coffee Mode & Persistent Idle Inhibition
- **Decision:** Coffee Mode (`SUPER + CTRL + U`) acts as an authoritative, persistent systemd inhibitor against idle blanking and system suspend.
- **Architecture:**
  - In [`dotfiles/hypr/hypridle.conf`](file:///home/realdhiru/nix/dotfiles/hypr/hypridle.conf), idle timeouts enforce DPMS off at 120s, lock-session at 150s, and system suspend at 1800s (30 minutes). Inhibitor flags (`ignore_dbus_inhibit = false`, `ignore_systemd_inhibit = false`) ensure full compliance with systemd inhibitor locks.
  - [`power.sh inhibit`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/power.sh) engages `systemd-inhibit --what=idle:sleep --who=idle-inhibit-toggle --why="Coffee mode (idle inhibit)" --mode=block sleep infinity`.
  - State is canonically persisted in `~/.cache/quickshell/state.json` under `modes.coffee`.
  - [`restore_state.sh`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/restore_state.sh) re-acquires the inhibitor on QuickShell reloads, Hyprland restarts, and cold boots whenever `modes.coffee == true`, ensuring Coffee Mode survives desktop lifecycle events until explicitly deactivated by the user.

### 22. Minimal Notification Signal Architecture (Zero Sentence Body Text)
- **Decision:** Desktop notifications (`notify-send`) across all scripts and services must adhere strictly to ultra-minimal signal length (1–3 words maximum, e.g. `"Coffee mode ON"`, `"Game Mode OFF"`, `"Hotspot ON"`).
- **Rationale:** The TopBar ticker ([`NotifTicker.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/NotifTicker.qml)) and desktop popup overlays are tuned for concise, glanceable telemetry. Emitting conversational sentences or descriptive bodies clutters the UI layout, clips typography, and destroys the minimalist desktop aesthetic. Body strings are banned unless strictly conveying essential dynamic data (such as SSID or IP address).

### 23. Deterministic Single-Pass Positioning & Zero Morphing (WallpaperPicker Proof of Concept)
- **Decision:** In full-screen popup overlays (`WallpaperPicker.qml`), container coordinates snap deterministically on frame 0 without physical size interpolation (`Behavior on x / width / height` banned). All deferred settle timers (`settleTimer`) and multi-pass repositioning chains are eliminated.
- **Rationale:** Deferred positioning timers (e.g. 80ms) and multi-pass `forceLayout()` calls cause visible secondary refreshes, layout micro-jumps, and perceived UI lag right after opening. Snapping to final coordinates on frame 0 and executing a single positioning pass immediately upon `window.visible && view.width > 0` with `highlightMoveDuration: 0` guarantees rock-solid initial presentation while allowing smooth 350ms animated transitions for user-driven interactions thereafter.

### 24. Single-Instance QuickShell IPC Reload & Visual Theme Swatches
- **Decision:** QuickShell updates must never be applied by launching a secondary `quickshell -p ...` background process. Reloads must execute via native D-Bus IPC (`quickshell ipc -p ~/.config/hypr/scripts/quickshell/Shell.qml call main forceReload`) or `qs_manager.sh reload`.
- **Theme Swatch Buttons:** Category filter tabs in `WallpaperPicker.qml` replace text labels with dual-tone color gradient swatches (`dark`, `emerald`, `gruvbox`, `light`, `nord`, `ocean`, `sakura`, `sunset`, `synthwave`) inside 44px liquid glass capsules, filtering the carousel via `categoryProxyModel` and subfolder filename markers.

### 25. SideBar Dynamic Parity & Multi-Tier Control Pills
- **Decision:** Vertical `SideBar.qml` mirrors TopBar functionality and aesthetics without compromising center-locked geometry:
  - **Dynamic Occupied-Only Workspaces**: Filters empty workspaces dynamically, rendering only `active` and `occupied` slots via Japanese Kanji numerals with vertical sliding highlight tracking (`activeHighlight`).
  - **Unified Multi-Tier Status Pills**: Replaced separate one-off pills with two-tiered split pills (WiFi + Bluetooth, Brightness/Sunset + Volume) sharing a unified 1px divider, preserving vertical bar density while supporting transient feedback and mouse wheel scrolling.
  - **Flat Rectangular CAVA Segments**: CAVA audio visualizer bars use flat rectangular geometry (`radius: barWindow.s(1)`) with moderate sensitivity (`sensitivity = 70`) matching TopBar visual standards.

### 26. Dynamic Monitor Geometry & Resolution Pickers
- **Decision:** No monitor resolution literal may remain in QuickShell layout/simulation code. `Main.qml` offscreen-preload geometry reads live `masterWindow.screen` (fallback `Quickshell.screens[0]`); `MonitorPopup.qml` resolution/refresh pickers are generated from Hyprland `availableModes` (union with curated presets, deduped/sorted, distinct even-row padding, derived keyboard bounds). Lutris gamescope game/output res stays empty (native) globally and per-game.
- **Ops:** When Hyprland IPC is wedged, `qs_manager.sh reload` can hang on its `hyprctl eval` step — diagnose IPC first (`hyprctl monitors -j`), and prefer direct `quickshell ipc ... call main forceReload` on a healthy session.

### 27. ESC Handling, Preview Aspect, Per-Mode Rates
- **Decision:** No widget may register its own `Shortcut{sequence:"Escape"}` competing with `Main.qml`'s global one in the same window. ESC uses `Keys.onEscapePressed` bubbling (exit sub-state first, else fall through to the widgetStack hide handler). Monitor preview mock preserves true panel aspect via fit-box. Rate picker lists only EDID-advertised rates for the selected resolution; ListModel role writes are paired with an epoch counter where bindings read via `.get()`.
- **Grid delegate hygiene:** never shadow Repeater's built-in `modelData` with an index binding (`window.list[index]`) — recycled delegates render stale tiles as phantom duplicates. Data pollers must not wipe+rebuild their model on every view activation (loses unapplied edits, flashes grid); populate-once with explicit refresh.

### 28. Cached-Widget Refresh Contract, SNI Tray Constraints & UPower Battery Source
- **Decision:** Cached popups (`Main.qml` `widgetCache`) refresh in `showWidget()`, never in `onVisibleChanged`. `targetObj.visible` is set `true` once and never reset, so `onVisibleChanged` fires once per process; any `enabled: window.visible` / `running: window.visible` stays armed forever unless reset per-open. Clipboard paste declares MIME explicitly and serializes copy→close through a single `Process.onExited`.
- **Decision:** System-tray icons are register-once SNI clients. A watcher restart (any QuickShell restart) empties the tray until the client apps restart — there is no re-scan. The KDE Connect icon requires `kdeconnect-indicator` (`kdeconnectd` exports no `StatusNotifierItem`); EasyEffects `--service-mode` and `blueman-applet` (GtkStatusIcon) can never appear. Tray renderers must not denylist `kdeconnect` while the indicator is autostarted.
- **Decision:** Battery runtime telemetry comes from `Quickshell.Services.UPower` only (`UPower.displayDevice` on the system bus: `energy`, `energyCapacity`, `changeRate`, `timeToFull`). Extends rule 3's sysfs-inotify ban: no `FileView` on `/sys`, no coalescing `Timer` (polling by another name). `UPowerDevice.isLaptopBattery` matches both the synthetic `DisplayDevice` aggregate and the real pack — always source `displayDevice` (never null, no enumeration race). Hover readout is an in-bar glyph↔text swap; the bar surface is never widened for tooltips.

### 29. Shared Media Backend, Solid-Mode Existence Watches & No Destructive Signals
- **Decision:** All MPRIS/music/cava telemetry lives in root `MusicState.qml` (pragma Singleton). `TopBar.qml`/`SideBar.qml` are presentation-only and alias it (`property var musicData: MusicState.musicData`, …). No bar may own `playerctl --follow`, `music_info.sh`, json `FileView`, `cava`, or media timers — exactly one of each globally, independent of bar visibility. UI files are never merged for backend sharing.
- **Decision:** Marker-file `FileView`s (`wallpaper_killed`, `gaming_mode`) must pair `watchChanges` with `onFileChanged: { reload(); updateSolidMode(); }`. Directory-watch fires the signal on create/delete but the buffer stays stale without an explicit reload (quickshell `fileview.cpp`: `onWatchedDirectoryChanged` only emits; `powerProfileWatcher` already had the correct pattern). Without this, runtime state flips never propagate.
- **Decision:** Never `pkill -HUP wezterm-gui` (or any terminal) to "reload" config — SIGHUP terminates it and kills every pane. Wezterm hot-reloads on config mtime; `touch` the color/config files instead.

### 30. Shared Coffee State, wpctl-Only Volume Writes & Reload Orphan Reaping
- **Decision:** Coffee mode state lives only in `SysData.coffeeActive` (synced from `state.json`); all trays read it, all writes go through `SysData.setCoffee()`. No widget may own a parallel coffee FileView.
- **Decision:** All volume writes go through `wpctl` (`set-mute`/`set-volume` on `@DEFAULT_AUDIO_SINK@`, mirroring `osd.sh` incl. unmute-on-raise and 100% cap). Native `sink.audio.*` writes silently no-op on stale nodes with no detectable failure — Pipewire stays read-only for display. `toggle volume` targets nothing (no such widget); volume clicks open the battery popup.
- **Decision:** Every QML-owned persistent `Process` gets explicit stops in `Component.onDestruction` — engine reload does not reliably SIGTERM children, orphaning one set per reload (observed 8× `playerctl --follow` at PPID 1). Verified: repeated `forceReload` holds exactly the live set, zero orphans.
- **Decision:** Battery direction comes only from `UPower.onBattery`. `timeToFull` is 0 whenever UPower can't estimate — branching on it runs discharge math while charging ("25h on AC"). AC without active fill, and any estimate over 10h, displays `"AC"`; pill text clamps at 11:59.
- **Decision:** After editing, verify non-ASCII string literals (nerd glyphs, CJK) with `hexdump` — tool output renders them invisibly and they can be silently dropped to `""`, producing blank-but-laid-out widgets.

### 31. No Positioning Against Animating Geometry, Orphan Reaping & OOM Guard
- **Decision (revert lesson):** Never offset layout against live height animations (`childrenRect`/implicitHeight bindings driving anchors). The offset recomputes mid-animation and fights the layout's own tweens — jitter, shadows, drift. Workspace capsule stays locked at true center; optical balance is achieved by content design, not runtime shifting.
- **Decision:** `qs_manager.sh` brutal paths (`reload`, quickshell toggle) reap only PPID-1 strays of quickshell-spawned followers (exact full-command patterns). Live children and clipboard owners are never matched.
- **Decision:** `services.earlyoom` (`freeMemThreshold=5`, `freeSwapThreshold=100`, avoid compositor/shell) is the freeze guard: 23GB swap means the kernel OOM never fires in time under thrash; userspace must SIGTERM the hog at <5% available. macOS (compressed memory + Jetsam) and Windows (compression + app lifecycle kills) both ship such guards; desktop Linux/NixOS does not by default.

### 32. Toggle-Effect Ordering, Native Model Signals, Boot-Critical Reads
- **Decision:** Toggleable tray adornments (coffee) render LAST so their appearance never displaces stable icons. Same rule both trays.
- **Decision:** Plain Hyprland binds cannot require "both Alts" (pressed Alt counts toward the mod mask) — deliberate chords add a real modifier (CTRL), documented inline. Never work around with submaps/timers.
- **Decision:** Cold-start model sync uses the backend's own change signals (`Hyprland.workspaces/toplevels.valuesChanged`), never deferred timers. One-shot timers are polling with a nicer name when the event source exists.
- **Decision:** Boot-critical `FileView`s (settings.json) use `blockLoading: true` so first-frame bindings see real values. Async-first-read leaves defaults live (wrong bar flashes) until load lands.





