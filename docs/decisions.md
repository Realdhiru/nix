# Architecture Decision Records (ADR)

Concise, permanent architectural invariants and technical rationale. Do not duplicate daily commit logs here (use `CHANGELOG.md`).


### ADR-001: Hardware-Accelerated Video & GIF Wallpaper Architecture via mpvpaper
- **Decision:**
  1. Animated GIFs and videos (`mp4`, `mkv`, `mov`, `webm`, `gif`) are routed to `mpvpaper` with auto-pause (`-p`) and fixed-function hardware VA-API video decode (`--hwdec=auto-safe`).
  2. In `home.nix`, systemd user template unit `mpvpaper@.service` strictly uses specifier `%i` (verbatim output name, preserving dashes). `%I` unescapes dashes to slashes (`eDP-1` $\rightarrow$ `eDP/1`), causing output discovery failure in Wayland.
  3. GIFs play immediately with 0ms delay in `mpvpaper` while converting to `.mp4` into `~/.cache/converted_gifs/` asynchronously; `thumbnail.sh` also pre-converts GIFs in the background. Subsequent plays utilize the hardware-decoded MP4 with zero CPU draw.
  4. Static images use `awww` with `--filter Bilinear` and transition `none`, applying in < 0.1s.
- **Rationale:** Decoding multi-hundred-frame GIFs in software inside `awww` generated hundreds of megabytes of uncompressed frame rasters, causing 8–32s stalls and draining battery. Delegating GIFs to `mpvpaper` with hardware offload reduces apply time from 8s to <0.15s. Auto-pause (`-p`) halts decoding whenever active windows obscure the wallpaper, preserving deep C-states ($C8/C10$).

---

### ADR-002: WirePlumber Diagnostic Telemetry & Wallpaper Subsystem Carousel/Cycling Cohesion
- **Decision:**
  1. WirePlumber diagnostic event logging is configured declaratively in NixOS (`modules/system/services.nix`) via `systemd.user.services.wireplumber.environment.WIREPLUMBER_DEBUG = "I,s-linking:D,s-default-nodes:D"`. All endpoint additions, linking decisions, and node fallbacks are captured in systemd journal.
  2. `WallpaperPicker.qml` carousel translation duration `highlightMoveDuration` is strictly bound to `Motion.moveMs` (220ms), with `scrollThreshold` tuned to `s(40)` and throttle at 50ms, eliminating coordinate desynchronization with delegate resizing.
  3. `cycle_wallpaper.sh` enforces timestamp-based validation on `target_wallpaper.txt`: if `current_wallpaper.txt` is newer or `target_wallpaper.txt` is older than 2s, it is invalidated and removed. Applying any wallpaper outside rapid cycling (`backend/set.sh`) unconditionally clears `target_wallpaper.txt`, ensuring cyclic navigation always starts from the currently active wallpaper.
  4. Wallpaper kill debounce in `wallpaper.sh` is lowered to 180ms to permit swift, repeated keybind toggles without dropped actions or full compositor reloads.
- **Rationale:** Intermittent audio drops cannot be reliably resolved by speculation without event traces; persistent topic-specific WirePlumber logging in journald captures every target link decision without runtime overhead. In `WallpaperPicker.qml`, mismatched durations (350ms move vs 220ms delegate size) caused jarring snap physics during horizontal scrolling. In `cycle_wallpaper.sh`, an un-cleared `target_wallpaper.txt` persisted indefinitely, causing cyclic navigation to jump to outdated wallpapers rather than cycling contiguous neighbors of the active wallpaper.

---

### ADR-003: Declarative Single-Source-of-Truth Monitor Modes, Layer Blur Narrowing & hyprsunset Hardening
- **Decision:**
  1. `refresh_monitor.sh` selects the configured AC/battery refresh from Hyprland `availableModes` outside the compositor, then sends one `hyprctl eval` containing only `hl.monitor()`. Startup, explicit profile changes, and power-supply events share this script. It must not launch a nested `hyprctl` query from inside that eval: the live service timed out while the compositor was servicing the outer IPC request. `$DESKTOP_STATE_DIR/monitors/intent.json` remains the sole monitor authority for layout, resolution, scale, transform, and placement; the script serializes its refresh-only merge with the monitor UI writers.
  2. Compositor layer blur is narrowed strictly to `^(quickshell|qs-master|qs-notif-toast)$`. The full-screen overlay surface `qs-floating-overlay` is excluded from GPU blur passes, eliminating unneeded compositor render costs.
  3. `hyprsunset` is supervised declaratively as a systemd user unit (`hyprsunset.service`) with `Restart=on-failure`. The QML slider in `SunsetPopup.qml` communicates directly with the running daemon via `hyprctl hyprsunset` with a 40ms throttle and final apply on release. All `systemctl start/stop`, `pgrep`, `pkill`, subshells, and `sleep` are removed from QML.
- **Rationale:** Reading EDID detailed timings failed when the panel EDID file was empty and the old cache/transform files let power events replace the UI's monitor choice. Hyprland-reported modes avoid the EDID dependency; changing only the mode refresh while preserving intent prevents a power event from resetting resolution, placement, scale, transform, or an external-only layout. Blurring the full-screen transparent `qs-floating-overlay` layer incurred wasteful texture passes on every frame. Bombarding `hyprsunset` with un-debounced slider ticks and imperative subshells caused Hyprland CTM commit crashes (`_ZN29CCHyprlandCtmControlManagerV110sendCommitEv`). Supervising `hyprsunset` under systemd and debouncing commits eliminated crashes while restoring GPU RC6 residency to 43.56% and reducing Hyprland CPU by 33.3%.

---

### ADR-004: Wallpaper State Migration ($XDG_STATE_HOME) & D-Bus Notification Close Invariants
- **Decision:** Wallpaper state is strictly maintained under `${XDG_STATE_HOME:-$HOME/.local/state}/desktop/wallpaper/` using atomic writes (`tmp + mv -f` in the same directory). No sentinel values (`"none"`) are written to state files; `current_wallpaper.txt` always stores the authoritative valid wallpaper path, while disabled/killed state is tracked natively via Quickshell's modes state. UI state synchronization uses `FolderListModel` directory watching to detect atomic renames without losing inode tracking. Boot never falls back to random directory scans; it resolves declarative `$DEFAULT_WALLPAPER` (Nix store derivation) or exits 1 with a descriptive error. Notification teardown distinguishes between D-Bus `CloseNotification` (reason 3 `CloseRequested`), user dismissal (reason 2 `Dismissed`), and timeout expiration (reason 1 `Expired`).
- **Rationale:** Writing state files to `~/.cache` without atomic renames caused zero-byte corruption when keybinds or processes toggled wallpaper state concurrently. Inotify watchers on file inodes lose event notifications on atomic `rename()` / `mv`, which was resolved by directory monitoring via `FolderListModel`. Reading empty files caused `cmd_boot` to invoke `find` and select arbitrary wallpapers. In FreeDesktop Notifications and Quickshell's `NotificationServer`, timeouts must call `expire()` so external clients receive reason 1 instead of reason 2.

---

### ADR-005: Power Button Display Power Toggle & DPMS Wakeup Invariants
- **Decision:** Bind physical power button (`XF86PowerOff`) directly to `power.sh display toggle` with `{ locked = true }`. Set `services.logind.settings.Login.HandlePowerKey = "ignore"` (and run user inhibitor `inhibit-power-key`). Enable `key_press_enables_dpms = true` and `mouse_move_enables_dpms = true` in [`misc.lua`](file:///home/realdhiru/nix/dotfiles/hypr/misc.lua).
- **Rationale:** Coffee mode (`SUPER + CTRL + U`) holds a systemd `idle:sleep` inhibitor so background AI agents and long batch compilations do not trigger automated `systemctl suspend` after 30 minutes of inactivity. However, inhibiting `idle` halts hypridle's automated DPMS timeout (120s). Previously, turning DPMS off manually when `key_press_enables_dpms` was `false` left the user permanently trapped with a black screen because hypridle could not trigger `on-resume` and Hyprland ignored key/mouse events. Binding the power button (`XF86PowerOff`) provides an intuitive hardware screen toggle, while `key_press_enables_dpms` and `mouse_move_enables_dpms` ensure any keyboard or trackpad interaction immediately restores the OLED panel ($0\text{W} \leftrightarrow 100\%$).

---

### ADR-006: Dynamic Island Notification Toast & Contrast Floor Token
- **Decision:** When TopBar is in Sidebar mode, notifications display via a top-centered Dynamic Island morphing pill (`NotifToast.qml`) governed by a derived `Config.toastOpacity` token (`Math.max(0.70, config.effectivePopupOpacity)`). The Wayland LayerShell surface uses `exclusionMode: ExclusionMode.Ignore` and explicit `mask: Region { item: toastCard }`.
- **Rationale:** Popups standard opacity (`0.14`) fails WCAG AA readability (measured contrast 1.05:1–1.36:1) against bright wallpapers. The `toastOpacity: 0.70` floor ensures $\ge 5.37:1$ contrast for body text without breaking dark mode theming or adding hardcoded colors. `ExclusionMode.Ignore` prevents Hyprland exclusive monitor margin offsets from displacing the toast down the screen.

---

### ADR-007: Dynamic Multi-Monitor Layout Intent & Wallpaper Lifecycle Architecture
- **Decision:** Monitor layout and per-output settings live in `$DESKTOP_STATE_DIR/monitors/intent.json`, keyed by stable output description where available. The layout accepts `internal`, `external`, `mirror`, or `extend`; each display stores mode, scale, transform, and placement. Hyprland's native Lua runtime reads this state. Wallpaper daemons are declared as systemd user services (`awww-daemon.service`, `mpvpaper@<out>.service`), with active video endpoints tracked via `%h/.local/state/mpvpaper/%i.env`. In `set.sh`, all target monitors are resolved upfront and strictly passed via `--outputs "$OUT_JOINED"`, with filter explicitly set to `--filter Nearest` for animated GIFs and `--filter Bilinear` for static images. In systemd, `mpvpaper@.service` must use `%i` (verbatim output name) instead of `%I` (unescaped instance name).
- **Rationale:** Persisting settings by output description survives connector-name changes and prevents power-refresh events from overwriting the UI's selected layout or display properties. Without `--outputs`, `awww img` invokes `update_disconnected_caches()` which reads every uncompressed frame cache file from disk, stalling wallpaper switches. Default `Lanczos3` scaling on multi-frame GIFs consumes 30+ seconds of CPU time across 100+ frames; `--filter Nearest` decodes and renders in <0.2s. Using `%I` in systemd unescaped `eDP-1` to `eDP/1`, causing `mpvpaper` to fail finding the Wayland display.


### ADR-008: HiDPI Toolkit Coordinate Synchronization & Popup Anchoring
- **Decision:** Declare `GDK_SCALE = "2"`, `QT_AUTO_SCREEN_SCALE_FACTOR = "1"`, and `QT_ENABLE_HIGHDPI_SCALING = "1"` in [`env.lua`](file:///home/realdhiru/nix/dotfiles/hypr/env.lua). Add `--disable-features=DownloadBubble,DownloadBubbleV2` to the Brave launcher in [`home.nix`](file:///home/realdhiru/nix/home.nix).
- **Rationale:** On a 2.0x display (2880×1620), omitting explicit toolkit scale hints causes GTK/Qt/Chromium subsurfaces to compute popup, menu, and dropdown anchor rects against raw physical buffer coordinates. When windows sit near monitor boundaries, `xdg_positioner` flips or clamps the misplaced coordinates off-screen. Disabling the Chromium Download Bubble eliminates the detached subsurface in frameless PWAs (`--app=...`) in favor of stable in-window download progress.

---

### ADR-009: User & Credential Parameterization (`user.nix`)
- **Decision:** [`user.nix`](file:///home/realdhiru/nix/user.nix) is the single source of truth for `username`, `name`, and `hostname`.
- **Rationale:** Banished hardcoded `/home/username` across Nix modules, Lua scripts, and Wallust configs for portability. All modules consume `user.username`.

### ADR-010: Understandable, Declarative System Ownership
- **Decision:** Prefer small, inspectable components and configuration in this repository over opaque frameworks or imperative machine-only setup. Declare packages and services in Nix; use the existing live-linked dotfile workflow where fast iteration is intentional.
- **Rationale:** Reproducibility matters, but the system must also remain understandable and debuggable by its owner. Nix is not a guarantee of bit-identical results across hardware; keep host-specific state explicit and verify changes against the actual machine.

### ADR-011: Documentation Scope
- **Decision:** Keep this repository's docs focused on this machine's configuration, architecture choices, measured behavior, and operational runbooks. General Linux, Wayland, Nix, and NixOS learning material belongs in the separate Obsidian vault at `~/Projects/Vault/nix-brain/`.
- **Rationale:** Separate system-of-record details from reusable teaching material to avoid maintaining duplicated explanations. Keep only the rationale needed to understand a local decision here.
- **Application:** General flake, standalone packaging, and store-versus-live-link tutorials have been reduced to local input workflow, package ownership, and desktop iteration choices. Preserve the real local topology and observed behavior here.

### ADR-012: Second-Brain Knowledge Base & Personal Biodata Standards
- **Decision:** Personal biodata and profile history in `~/Projects/Vault/personal/` must follow strict machine-readable tabular schemas (`| Tag | Fact | First Seen | Last Seen | Confidence | Frequency | Sources |`) with explicit provenance, zero duplicates, zero contradictory entries, and zero negative-knowledge boilerplate.
- **Rules:**
  - Degree program is authoritative as **B.Tech in Information Technology (IT)** at KIET Group of Institutions, Ghaziabad. Informal mentions of CS/CSIT in chat exports are superseded.
  - Academic standing is tracked via bounded time-invariant dates (**2024–2028 Batch**, expected graduation August 2028) rather than relative, expiring year numbers.
  - Current residence is **Ghaziabad, Delhi NCR (Uttar Pradesh)**; hometown / origin is **Bareilly, Uttar Pradesh, India**.
  - Internal OLED display resolution is empirically anchored to **2880×1620 @ 120Hz (16:9, Samsung Display Corp. 0x4180)**. Speculative 2880×1800 (16:10) labels are removed.
  - Negative placeholder rows ("no named people identified", "no friends on record") from automated AI memory exports are purged to maintain high signal-to-noise ratio.

### ADR-013: Multi-Vault Ecosystem Authority
- **Decision:** All knowledge bases outside `~/nix/docs` live directly under `~/Projects/Vault/`, each serving an orthogonal domain under the high-density systems whitepaper standard:
  - **`nix-brain`**: Universal Linux kernel primitives, IPC, graphics/audio pipelines, and Nix functional language calculus.
  - **`network-brain`**: Computer networking, IP addressing, transport protocols, firewalls, threat modeling, cryptography, SSH, VPNs/mesh overlays, Linux/NixOS network administration, hands-on lab runbooks, and misconception debunking.
  - **`game-brain`**: Wine/Proton graphics layers, DXVK/VKD3D, prefix sandboxing, and Iris Xe gaming configurations.
  - **`neobrowser-brain`**: Bubblewrap sandbox containment, Xephyr `:7` X11 server displays, and anti-tamper runtime mechanics.
  - **`procrastinate`**: Curated reading backlog and structured learning index for deep learning architectures, distributed computing, and emerging software paradigms.


### ADR-014: Power Management & Hardware Authority
- **Decision:** TLP 1.10.2 is the sole hardware authority for platform profiles, EPP, ASPM, USB autosuspend, and Intel GPU frequency policy.
- **Rules:**
  - `asusd.service` is enabled strictly for the 80% charge ceiling. Firmware profile switching remains disabled in `asusd.ron`.
  - `power.sh profile` issues only `sudo tlp <profile>`; it records/synchronizes state only after TLP succeeds. It does not write `/sys/firmware/acpi/platform_profile` or invoke `asusctl`.
  - Power Saver keeps `PLATFORM_PROFILE_ON_SAV = "balanced"` for the user's fan behavior; its EPP, boost, and CPU cap remain the declared SAV values in `power.nix`.
  - Balanced battery settings (`balance_performance`, turbo enabled, platform profile `balanced`, ASPM `powersupersave`, CPU max performance 100%) are an empirically locked user preference.
  - `boot.kernelParams` disables `nmi_watchdog` system-wide; `NMI_WATCHDOG=0` is not a battery-only setting.
  - Retain global `usbcore.autosuspend=-1` after the historical webcam streaming stability issue; no VID:PID was recorded, so TLP sets `USB_AUTOSUSPEND=0` rather than targeting one device.
  - Intel Iris Xe battery frequencies are bounded by hardware values (`MIN=100`, `MAX=1450`, `BOOST=1450` MHz).
  - `asusd.service` still owns only charge-threshold enforcement; profile transitions are managed by TLP and `SysData.qml`.

### ADR-015: QuickShell Architecture & IPC
- **Decision:** Native C++ event-driven bindings only (`Quickshell.Hyprland`, `Quickshell.Services.Pipewire`, `FileView { watchChanges: true }`, `FileWatcher`).
- **Rationale:** Event bindings are preferred to recurring subprocess loops in QML. Bounded clocks and accounting remain where required: FocusTime records at one-second resolution and publishes live JSON on app changes or every 15 seconds; the battery auditor samples every 60 seconds while discharging. These intervals are documented rather than described as zero polling.

### ADR-016: Fast Compiled Execution & Zero-Python Hot Paths
- **Decision:** Python, Node.js, and heavy interpreted runtimes are strictly prohibited from hot interactive paths (keybind execution, status polling, wallpaper cycling, clipboard fetching, theme generation).
- **Rationale:** Python startup introduces an unavoidable ~80–150ms interpreter bootstrap latency and continuous VM memory overhead. Interactive shell actions must complete in < 5ms.
- **Rules:**
  - All JSON reads and edits in hot shell scripts must use native compiled C utilities (`jq`).
  - Text and math processing in hooks must use POSIX C utilities (`awk`).
  - High-frequency utilities must use compiled native binaries (Rust / C++) or direct Wayland/PipeWire IPC.
  - Theme generation ([`generate.sh`](file:///home/realdhiru/nix/dotfiles/wallust/generate.sh)) relies directly on Wallust's native Rust extraction engine without ImageMagick/Python histogram overrides or synthetic monochrome fallbacks, preserving full 16-color ANSI terminal palettes.

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
  - **Child Module Opacity Inheritance**: Modular views loaded inside `Floating.qml` or layer containers (`Timer.qml`, `DrawAction.qml`) must never paint solid opaque backplates (`cMantle`, `solidBgColor`). The outer container owns the blurred translucent background; child views must remain transparent or use subtle alpha cards (`cSurface0` at 0.40) to preserve system glassmorphism.
  - **Native PipeWire Audio Alerts & Alarm Loop Invariant**: Desktop timers and Pomodoro notifications provide acoustic feedback using native `/run/current-system/sw/bin/pw-play` routed to standard Freedesktop stereo cues (`alarm-clock-elapsed.oga`, `complete.oga`), paired with minimal Rule 2.D notification titles. For Timer completions, audio loops (`isAlarmBuzzing`) at 6.2s intervals until dismissed, accompanied by programmatic Floating panel reveal (`floating setIndex 2`, `floating showEdge left`) and a 3-minute failsafe auto-silence timeout. Dismissal is bound to the center action button, `Enter`, or `Return`.
  - **Wallpaper Search Concurrency & Fast Break**: Online wallpaper ingest pipelines (`ddg_search.sh`) must never perform serial blocking HEAD requests against full remote images prior to fetching thumbnails. The pipeline must break immediately on zero-result API responses and stream downloads across a bounded 4-worker concurrency pool, keeping search latency under 2 seconds.
  - **Single Source of Truth for Wallpaper Ingest**: Online search scripts must exist exclusively in `dotfiles/wallpaper/backend/ddg_search.sh`. Never duplicate parallel helper scripts under `quickshell/wallpaper/`; QML callers must invoke canonical backend tools directly to prevent divergence.
  - **Universal Solid Mode Invariant**: When Solid Mode (`Config.isSolidMode`) is active (via `wallpaper.sh kill`, gaming mode, or power-saver), ALL container backgrounds and child element alphas (`Timer.qml`, `DrawAction.qml`, `ClipboardManager.qml`, `WallpaperPicker.qml`) must automatically collapse translucent alpha multipliers to 100% solid theme colors. State controllers (`state_ctl.sh`, `restore_state.sh`) must use non-zero file checks (`[ ! -s "$STATE_FILE" ]`) to guarantee automatic self-healing against empty cache files.
  - **Global Consistency & Mandatory Confirmation Rule**:
    - **Scope**: Applies to ANY visual/theme change across the entire system (QuickShell widgets, Fuzzel, hyprlock, topbar, window borders, `rules.lua` layer rules, etc.).
    - **No Local Overrides**: Visual properties (opacity, blur, tokens, borders, radius, spacing) must be applied across every widget/app sharing that visual category in a single pass using shared tokens.
    - **Mandatory Pre-Change Check-In**: Before executing any UI/look/theme change, the agent must pause, present the proposed changes and scope, and await explicit user confirmation before modifying files.
  - `Scaler` in popups must use `currentWidth: Screen.width` (single-pass). Never pass device-pixel bounds (`Config.masterWidth`) to prevent double-scaling clipping.
  - **Scene Visibility Gating for Positioning Math**: Any `ListView.positionViewAtIndex()` or layout settle logic in popup components must be strictly gated on `window.visible && view.width > 0`. Widgets are created on first open and cached, avoiding startup work from hidden `Component.onCompleted` handlers. If a future feature adds preloading, it must not start background work or query unmapped geometry while hidden.
  - **Dynamic HighlightRangeMode for Carousel Popups**: In full-width carousels (`WallpaperPicker`), `highlightRangeMode` must be dynamically gated (`initialFocusSet ? StrictlyEnforceRange : NoHighlightRange`). Static `StrictlyEnforceRange` forces negative `contentX` clamps (`-preferredHighlightBegin`) when mounting or unmounting in `StackView` before delegate items finish layout, causing viewport truncation and horizontal card displacement.
  - **Focus Preservation Across Model Re-Sorting**: In QuickShell ListModels where elements are sorted asynchronously by secondary telemetry (e.g. `sortListModel()` reordering by color/hue gradient upon `indexer.sh` completion), invoking `model.clear()` resets `ListView.currentIndex` to 0. Any sort mutation must preserve the target item identity and immediately restore focus via `executeFocusRestore(targetIdx, false, true)` after `model.append()` to prevent snapping to index 0.
  - **Workspace IPC Debouncing & Layout Tween Decoupling**: In workspace bar modules (`SideBar.qml`, `TopBar.qml`), multi-event burst signals (`onActiveToplevelChanged`, `onRawEvent`, `workspaces.onValuesChanged`, `toplevels.onValuesChanged`) must be coalesced through a single-flight 16ms timer (`wsDebounceTimer`). Never bind layout container offsets (`wsLayout.y`) to tweening dimensions (`implicitHeight`) during delegate mount/unmount animations, as it creates inter-frame coordinate fighting and highlight indicator jitter. Auto-scroll math must account for layout container positioning (`targetY = wsLayout.y + activeItem.y`).
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
  - **Primary Lockscreen Architecture**: Session locking is powered by native GPU-accelerated `hyprlock` (`ext-session-lock-v1`) with dynamic dual-pass screenshot blur (`path = screenshot`, `blur_passes = 2`) and instant PAM authentication (<20ms), triggered via `power.sh lock` and `hypridle`. The legacy `Lock.qml` (and QtMultimedia video lockscreen) is superseded to eliminate frame capture overhead and PAM session desyncs.

### ADR-017: Hardware Quirks Modularization (`hosts/nixos/hardware/`)
- **Isolation Boundary**: Machine-specific drivers, vendor daemons (`asusd`), and hardware quirks must reside strictly in host-level hardware modules (`hosts/<host>/hardware/`), never inside portable system modules (`modules/system/`).
- **ASUS Vivobook OLED (`asus.nix`):**
  - Thunderbolt 4 / Type-C Power Stabilization: Intel Raptor Lake Thunderbolt controller (`00:0d.0`, `00:0d.3`) is denylisted from aggressive runtime PM sleep (`RUNTIME_PM_DENYLIST`) to prevent `USBSTS 0x401` resume crashes and Type-C peripheral disconnects. Flawed custom UCSI udev rules were permanently removed in favor of TLP's native multi-source AC evaluation (`tlp auto`).

### ADR-018: Rebuild Safety Pipeline (`modules/home/shell.nix`, `scripts/health-check.sh`)
- **Decision:** All system switches must route through `rebuild()`.
- **Rationale:** Pre-records previous generation, stages/commits, performs health-gated validation (Hyprland alive + isolated alacritty GPU-hang probe), and executes automated rollback if critical checks fail. Bad generations are kept bootable in bootloader.
- **Default Terminal Architecture:** Alacritty serves as the default system terminal across keybinds (`Super + T`), application launcher (`fuzzel.ini`), file manager actions (`pcmanfm-qt`), and health validation probes. Foot remains installed and configured as an auxiliary terminal accessible from application launchers with normalized font size and Wallust glass-blur transparency.

### ADR-019: Declarative Symlinks & Theming
- **Decision:** Out-of-store symlinks (`mkOutOfStoreSymlink`) for `dotfiles/` to enable instant live reloading without rebuilds.
- **Decision:** Decoupled **Wallust** theme engine (`dotfiles/wallust/`) using Lch colorspace and 16 ANSI color extraction. Completely replaces Matugen. Emits all dynamic palette outputs to `~/.cache/theme/` (QuickShell, Foot, Alacritty, Cava, GTK, Qt).
- **Rule:** Wallust engine must remain strictly self-contained and portable; wallpaper handlers and QuickShell widgets communicate only via clean file contracts (`generate.sh <image>` and `~/.cache/theme/colors.json`).
- **Dark Mode Lock Rule:** Global theme defaults permanently to dark mode (`saliencedark16`). Wallpaper switches never trigger automatic light mode. Light mode is strictly manual via `settings.json` (`"themeMode": "light"`).
- **Single Theme Output Root:** `~/.cache/theme/` is the *only* runtime theme output. The legacy `~/.cache/matugen` compat tree has been removed — it had zero live consumers once GTK/Qt, terminal, and QuickShell all pointed at `~/.cache/theme`. New theme consumers must read `~/.cache/theme/` directly and must never reintroduce a second compat root.

### ADR-020: Application Packaging Authority: Standalone Flakes & Native Packaging (Distrobox Decommissioned)
- **Decision:** Purged Distrobox and Podman entirely. Standalone software and third-party packages must be packaged declaratively via custom Flakes, native Nix derivations (`pkgs/`), or Linux kernel `binfmt_misc` AppImage execution (`programs.appimage.enable = true`).
- **Rationale:** Containerized execution (`deb-box` via Distrobox/Podman) introduced filesystem corruption risks, resource exhaustion, and MIME association conflicts with the host. Standalone Flakes provide true Nix immutability, zero container runtime overhead, and atomic rollback integration.
- **System-Wide FHS Sandbox Process Lifecycle (`dieWithParent = false`):**
  - Applications packaged via `buildFHSEnv` / `buildFHSEnvChroot` (such as `onlyoffice-desktopeditors`, `lutris`, `bottles`, `chatgpt`, `appimage-run`, `protonup-qt`) are globally overlaid in [`flake.nix`](file:///home/realdhiru/nix/flake.nix) with `dieWithParent = false`. By default, Nixpkgs sets `dieWithParent = true` which injects Bubblewrap's `--die-with-parent` (`prctl(PR_SET_PDEATHSIG, SIGKILL)`). This caused any application opened from file managers (`pcmanfm-qt`), app finders, or terminals to immediately terminate when the parent window exited. Enforcing `dieWithParent = false` system-wide ensures all applications detach and reparent to `systemd --user` cleanly like native desktop binaries.

### ADR-021: Architectural Modularity & Subsystem Decoupling
- **Decision:** Strict modular boundaries across system features. No mixed files or tight cross-dependencies.
- **Subsystem Contracts:**
  - **Theming (`dotfiles/wallust/`)**: Portable standalone color engine. Contains extraction, PIL/Magick luminance math, template generation, neutral fallback mode (`./generate.sh --neutral`), and client reloads. Zero wallpaper or UI dependencies.
  - **Wallpaper (`dotfiles/wallpaper/`)**: Portable desktop background manager (`wallpaper.sh`). Encapsulates daemon lifecycles (`awww`, `mpvpaper`), fast thumbnail generation, directory inotify watching, and online DuckDuckGo search. Hands off to theme engine via clean one-line async execution (`$THEME_ENGINE "$WALLPAPER" &`).
  - **QuickShell Widgets**: QuickShell components (e.g. `wallpaper/`, `network/`, `music/`, `calendar/`) must remain self-contained with localized `Scaler.qml` and `Theme` adapters, eliminating `import "../"` parent breakages when copied to other QuickShell environments.

### ADR-022: System Tray Architecture & Frameless Liquid Glass Design
- **Decision:** System Tray moved from TopBar into Battery Popup. Frameless (zero-border) visual standard across QuickShell.
- **Rationale:**
  - Status bar declutter: TopBar remains minimal, preserving space for dynamic workspace pills, CAVA audio visualizer with top-to-bottom vertical gradient, and clock/date.
  - Tray access consolidated: Quick access tray icons live directly alongside system controls (DND, volume, brightness, power profiles) in BatteryPopup header.
  - Zero-border design: Explicitly removed artificial hairline borders, rotating shape masks, and outer stroke containers across all widget popups (`MusicPopup`, `BatteryPopup`, `CalendarPopup`, `PopupCard`, `MonitorPopup`, `FocusTimePopup`, `NetworkPopup`, `ClipboardManager`). Default `borderWidth = 0` and `borderOpacity = 0.0` in `settings.json`.

### ADR-023: Terminal Dynamic ANSI Extraction & OLED Surface Authority
- **Dynamic Wallpaper-Extracted ANSI Palette (`ansidark16` + `lchansi`):**
  - Configured Wallust with `--colorspace lchansi --palette ansidark16 --check-contrast` in [`dotfiles/wallust/wallust.toml`](file:///home/realdhiru/nix/dotfiles/wallust/wallust.toml) and [`dotfiles/wallust/generate.sh`](file:///home/realdhiru/nix/dotfiles/wallust/generate.sh).
  - All terminal ANSI slots (`color0`-`color15`), foreground, background, and cursor in terminal templates ([`foot.ini`](file:///home/realdhiru/nix/dotfiles/wallust/templates/foot.ini), [`alacritty.toml`](file:///home/realdhiru/nix/dotfiles/wallust/templates/alacritty.toml)) are dynamically derived from the wallpaper while preserving standard ANSI hue roles (red, green, blue, etc.), preventing muddy cluster collisions.
- **Physical OLED Pitch-Black Root Compositor Background:**
  - In [`dotfiles/hypr/misc.lua`](file:///home/realdhiru/nix/dotfiles/hypr/misc.lua), `background_color = 0x000000` and `force_default_wallpaper = 0`.
  - When wallpaper daemons are terminated (`wallpaper.sh kill`), Hyprland renders pure `#000000`, turning off OLED pixels completely (0.000 nits, 0 mA draw) instead of illuminating the screen with Hyprland's default `0x111111` gray.
- **Deterministic Neutral Theme Bypass:**
  - In [`dotfiles/wallust/generate.sh`](file:///home/realdhiru/nix/dotfiles/wallust/generate.sh), `--neutral` bypasses Wallust salience clustering and ImageMagick histogram extraction, deterministically generating an OLED pitch-black palette without risk of false olive-green color spikes.

### ADR-024: Bootloader Generation Retention & EFI Partition Protection
- **Decision:** Strict `boot.loader.systemd-boot.configurationLimit = 10` in [`modules/system/boot.nix`](file:///home/realdhiru/nix/modules/system/boot.nix).
- **Rationale:** The physical EFI system partition is 511MB. Without an explicit retention limit, systemd-boot generates kernel/initrd pairs in `/boot/EFI/nixos/` indefinitely. Setting a hard limit of 10 keeps rollback entries safe while guaranteeing `/boot` disk usage remains below 200MB (~40% capacity).

### ADR-025: Declarative Default Browser & MIME Authority
- **Decision:** Permanent declarative browser authority in `home.nix` (`http`, `https`, `text/html` locked to `brave-browser.desktop`).
- **Rationale:** Desktop applications and `.desktop` files must never inject or alter system-wide web protocols or default associations. Custom application schemes (e.g. `x-scheme-handler/codex`) are isolated declaratively.

### ADR-026: Nix Context Delivery (AGENTS.md as Router)
- **Decision:** [`AGENTS.md`](file:///home/realdhiru/nix/AGENTS.md) is an always-loaded **router**, not an archive. It carries only architecture facts an agent needs to navigate plus a pointer table from intent to file.
- **Rationale:** Home-manager and editor tooling inject `AGENTS.md` into every session. Mirroring `README.md`/docs into it wastes context on every request. Detailed docs stay on disk and are read on demand.
- **Rules:**
  - `AGENTS.md` must state flake inputs and the floating-pin policy, the module tree map, the Home Manager single entry point (`home.nix`), the `pkgs/` overlay set, and the `flake check` verification command.
  - Each linked doc gets a one-line "read when…" trigger so the agent knows when loading it pays for itself.
  - `repomix-output.xml` (~1.5MB) must carry an explicit do-not-read instruction.
  - Newly added systemic rules are promoted here only after they are stable; day-to-day change history belongs in `CHANGELOG.md`, architectural rationale in this file.

### ADR-027: File Watcher Semantics & Atomic Write Policy (`Quickshell.Io.FileView` vs Raw `inotifywait`)
- **Empirical Finding:** `Quickshell.Io.FileView` watches by **PATH**, not by inode. It automatically re-arms its watcher across atomic `mv` replacements as well as in-place `cat >` writes (`textChanged` and `fileChanged` fire 100% reliably on both write modes).
- **Rule & Standardized Write Pattern:**
  - **QuickShell `FileView` Contracts (`colors.json`, `music_info.json`)**: Use atomic move (`.tmp` -> `mv`). Atomic move is 100% safe for `Quickshell.Io.FileView` path watchers and eliminates partial-read JSON parse errors during concurrent reads.
  - **Raw Bash / External Script Watchers (`inotifywait -e close_write ...`)**: Raw bash scripts using `inotifywait` on a single explicit file target (rather than watching an entire directory) attach to the underlying Linux inode. Executing `mv` replaces the inode, breaking single-file `inotifywait` handles. For legacy single-file script watchers, use in-place writes (`cat > target`).

### ADR-028: Projects Directory Deletion Protection Policy
- **Decision:** Files and directories inside `~/Projects/` are strictly protected from deletion.
- **Rationale:** `~/Projects/` contains user backups, reference repositories, and uncommitted project workspaces. Agents must never issue `rm` or delete operations against `~/Projects/` or any of its subdirectories.

### ADR-029: OLED Typography & Antialiasing Invariants
- **Decision:** On high-DPI OLED panels with non-standard subpixel layouts (Samsung OLED `eDP-1`), LCD RGB subpixel antialiasing produces red/blue chromatic fringing and edge ghosting.
- **Rules:**
  - In WezTerm ([`dotfiles/wezterm.lua`](file:///home/realdhiru/nix/dotfiles/wezterm.lua)), FreeType load and render targets must be set to `"Normal"` to force clean grayscale antialiasing.
  - In QuickShell / Qt Quick widgets ([`TopBar.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/TopBar.qml)), high-contrast text must use `renderType: Text.NativeRendering` to avoid Qt distance-field texture filtering chromatic fringing.

### ADR-030: Wayland Layer-Shell Geometry & Scaling Invariants
- **Decision:** All QuickShell `PanelWindow` overlay surfaces operate strictly in compositor logical coordinates (`1440x810` on `2880x1620` @ scale 2.0).
- **Rules:**
  - Never configure layer surfaces or popup positioning with raw physical pixel bounds (`2880x1620`). Sizing coordinates using physical dimensions places elements past the logical surface boundary, clipping them off-screen.
  - Sizing fallback in `Main.qml` must derive logical screen space from monitor physical dimensions divided by monitor scale (`Math.round(physWidth / scale)`), ensuring frame-0 and settled coordinates are identical with zero pixel displacement.

### ADR-031: QuickShell Light/Dark Glass Theme State Management
- **Decision:** Theme mode is controlled explicitly by the user via keybind (`SUPER + L`) rather than automatic wallpaper luminance classification.
- **Rationale:** Automatic wallpaper luminance detection fails on complex illustrations (e.g. bright artwork with dark accents) and forces unintended theme flips. Persisting `ui.themeMode` in `$DESKTOP_STATE_DIR/quickshell/state.json` provides user control across reloads and cold boots.
- **Rules:**
  - `SUPER + L` triggers [`dotfiles/hypr/scripts/quickshell/toggle_theme_mode.sh`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/toggle_theme_mode.sh) to toggle `ui.themeMode` between `"dark"` and `"light"`.
  - `Theme.qml` reads `state.json` via native `FileView` watcher and exposes `isLightMode`.
  - Light mode increases `antiBleedOpacity` to `0.35` and `effectivePopupOpacity` to `0.55` in [`Config.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/Config.qml) to guarantee high visual contrast over light background illustrations.

### ADR-032: Operational Verification Invariants & Anti-Patterns
- **Screenshot Debugging Ban (Token & Latency Discipline):**
  - Capturing full-screen screenshots via `grim` to verify UI states burns excessive context tokens, inflates turnaround latency, and provides zero semantic insight into internal state machines.
  - Verification must rely on deterministic log assertions (`console.log`), direct file inspection via `FileView` / `jq`, and native IPC queries. Screenshots are strictly reserved for user-requested visual design evaluations.
- **Authoritative Process Recovery vs Stale Artifact Reverse-Engineering:**
  - When QuickShell or helper daemons experience lifecycle shifts, dead PID files and abandoned IPC sockets (`/run/user/1000/quickshell/by-id/`) must not be reverse-engineered or polled.
  - Always query the live daemon dynamically (`pgrep -fa quickshell`) or execute an authoritative clean reload via [`reload.sh`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/reload.sh).
- **Responsive Compute over Artificial Throttling:**
  - Power conservation must never degrade interactive responsiveness. Throttling CPU governors (EPP `power` / `quiet`) degrades application launch times (IDE, browser) and induces UI compositing stutter.
  - True mobile efficiency is achieved via rapid race-to-sleep (`balance_performance`, balanced platform profile, hardware ASPM `powersupersave`) paired with automated idle suspension.

### ADR-033: Coffee Mode & Persistent Idle Inhibition
- **Decision:** Coffee Mode (`SUPER + CTRL + U`) acts as an authoritative, persistent systemd inhibitor against idle blanking and system suspend.
- **Architecture:**
  - In [`dotfiles/hypr/hypridle.conf`](file:///home/realdhiru/nix/dotfiles/hypr/hypridle.conf), idle timeouts enforce DPMS off at 120s, lock-session at 150s, and system suspend at 1800s (30 minutes). Inhibitor flags (`ignore_dbus_inhibit = false`, `ignore_systemd_inhibit = false`) ensure full compliance with systemd inhibitor locks.
  - [`power.sh inhibit`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/power.sh) engages `systemd-inhibit --what=idle:sleep --who=idle-inhibit-toggle --why="Coffee mode (idle inhibit)" --mode=block sleep infinity`.
  - State is canonically persisted in `$DESKTOP_STATE_DIR/modes/modes.json` under `active.coffee`.
  - [`restore_state.sh`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/restore_state.sh) re-acquires the inhibitor on QuickShell reloads, Hyprland restarts, and cold boots whenever `modes.coffee == true`, ensuring Coffee Mode survives desktop lifecycle events until explicitly deactivated by the user.

### ADR-034: Minimal Notification Signal Architecture & Dynamic Island Delivery
- **Decision:** Desktop notifications (`notify-send`) across all scripts and services must adhere strictly to ultra-minimal signal length (1–3 words maximum, e.g. `"Coffee ON"`, `"Game Mode OFF"`, `"AC Connected"`). Every notification call must pass `-a "<Category/App>"`. In SideBar mode (`Config.topBarPosition === "left"`), QuickShell serves notifications via a centered **iPhone Dynamic Island** overlay window (`NotifToast.qml`) without external daemons.
- **Rationale:** The TopBar ticker (`NotifTicker.qml`) and desktop popup overlays are tuned for concise, glanceable telemetry. Emitting conversational sentences or descriptive bodies clutters the UI layout, clips typography, and destroys the minimalist desktop aesthetic. Omitting `-a` causes libnotify to report `"notify-send"` or `"bash"` as the app. In SideBar mode, horizontal bar tickers cannot fit in vertical space; a centered Dynamic Island pill at the top edge (`anchors.top: true`, 8px margin) with Apple-style spring physics (`Easing.OutBack`), pitch OLED black styling, anti-bleed underlayer, and staggered content bloom delivers a cohesive notification experience with zero compositor buffer reallocations via dynamic `Region` masking.

### ADR-035: Battery Widget Minimalist Unification
- **Decision:** The battery widget (`BatteryPopup.qml`) is stripped of the redundant left-side notification panel and top utility pills (tray, battery time, DND). Card width is reduced to 480px (`WindowRegistry.js`). Remaining runtime (`Xh Ym LEFT / FULL`) is rendered directly inside the central circular battery ring.
- **Rationale:** The battery widget was bloated by an 801px split layout displaying an unused notification history panel alongside duplicate status buttons already present in the status bar. Integrating the time remaining directly inside the battery ring centralizes power telemetry into a single, cohesive visual hierarchy.

### ADR-036: On-Demand KDE Connect Lifecycle Authority
- **Decision:** KDE Connect must be manually toggled via `kdeconnect_toggle.sh` (`Super + Shift + K`) rather than running continuously in the background on battery.
- **Rationale:** On battery, idle `kdeconnectd` handles frequent LAN UDP broadcast packets, keeping the CPU and Wi-Fi interface out of low-power package C-states ($C8/C10$) and consuming ~80MB RAM. Launching `kdeconnect-indicator` on-demand triggers D-Bus activation for `kdeconnectd` and directly surfaces the native SNI tray applet with device battery, ping, and transfer menus in QuickShell's SystemTray. Toggling OFF terminates both processes cleanly.

### ADR-037: Deterministic Single-Pass Positioning & Zero Morphing (WallpaperPicker Proof of Concept)
- **Decision:** In full-screen popup overlays (`WallpaperPicker.qml`), container coordinates snap deterministically on frame 0 without physical size interpolation (`Behavior on x / width / height` banned). All deferred settle timers (`settleTimer`) and multi-pass repositioning chains are eliminated.
- **Rationale:** Deferred positioning timers (e.g. 80ms) and multi-pass `forceLayout()` calls cause visible secondary refreshes, layout micro-jumps, and perceived UI lag right after opening. Snapping to final coordinates on frame 0 and executing a single positioning pass immediately upon `window.visible && view.width > 0` with `highlightMoveDuration: 0` guarantees rock-solid initial presentation while allowing smooth 350ms animated transitions for user-driven interactions thereafter.

### ADR-038: Single-Instance QuickShell IPC Reload & Visual Theme Swatches
- **Decision:** QuickShell updates must never be applied by launching a secondary `quickshell -p ...` background process. Reloads must execute via native D-Bus IPC (`quickshell ipc -p ~/.config/hypr/scripts/quickshell/Shell.qml call main forceReload`) or `qs_manager.sh reload`.
- **Theme Swatch Buttons:** Category filter tabs in `WallpaperPicker.qml` replace text labels with dual-tone color gradient swatches (`dark`, `emerald`, `gruvbox`, `light`, `nord`, `ocean`, `sakura`, `sunset`, `synthwave`) inside 44px liquid glass capsules, filtering the carousel via `categoryProxyModel` and subfolder filename markers.

### ADR-039: SideBar Dynamic Parity & Multi-Tier Control Pills
- **Decision:** Vertical `SideBar.qml` mirrors TopBar functionality and aesthetics without compromising center-locked geometry:
  - **Dynamic Occupied-Only Workspaces**: Filters empty workspaces dynamically, rendering only `active` and `occupied` slots via Japanese Kanji numerals with vertical sliding highlight tracking (`activeHighlight`).
  - **Unified Multi-Tier Status Pills**: Replaced separate one-off pills with two-tiered split pills (WiFi + Bluetooth, Brightness/Sunset + Volume) sharing a unified 1px divider, preserving vertical bar density while supporting transient feedback and mouse wheel scrolling.
  - **Flat Rectangular CAVA Segments**: CAVA audio visualizer bars use flat rectangular geometry (`radius: barWindow.s(1)`) with moderate sensitivity (`sensitivity = 70`) matching TopBar visual standards.

### ADR-040: Dynamic Monitor Geometry & Resolution Pickers
- **Decision:** No monitor resolution literal may remain in QuickShell layout/simulation code. `Main.qml` offscreen-preload geometry reads live `masterWindow.screen` (fallback `Quickshell.screens[0]`); `MonitorPopup.qml` resolution/refresh pickers are generated from Hyprland `availableModes` (union with curated presets, deduped/sorted, distinct even-row padding, derived keyboard bounds). Lutris gamescope game/output res stays empty (native) globally and per-game.
- **Ops:** When Hyprland IPC is wedged, `qs_manager.sh reload` can hang on its `hyprctl eval` step — diagnose IPC first (`hyprctl monitors -j`), and prefer direct `quickshell ipc ... call main forceReload` on a healthy session.

### ADR-041: ESC Handling, Preview Aspect, Per-Mode Rates
- **Decision:** No widget may register its own `Shortcut{sequence:"Escape"}` competing with `Main.qml`'s global one in the same window. ESC uses `Keys.onEscapePressed` bubbling (exit sub-state first, else fall through to the widgetStack hide handler). Monitor preview mock preserves true panel aspect via fit-box. Rate picker lists only EDID-advertised rates for the selected resolution; ListModel role writes are paired with an epoch counter where bindings read via `.get()`.
- **Grid delegate hygiene:** never shadow Repeater's built-in `modelData` with an index binding (`window.list[index]`) — recycled delegates render stale tiles as phantom duplicates. Data pollers must not wipe+rebuild their model on every view activation (loses unapplied edits, flashes grid); populate-once with explicit refresh.

### ADR-042: Cached-Widget Refresh Contract, SNI Tray Constraints & UPower Battery Source
- **Decision:** Cached popups (`Main.qml` `widgetCache`) refresh in `showWidget()`, never in `onVisibleChanged`. `targetObj.visible` is set `true` once and never reset, so `onVisibleChanged` fires once per process; any `enabled: window.visible` / `running: window.visible` stays armed forever unless reset per-open. Clipboard paste declares MIME explicitly and serializes copy→close through a single `Process.onExited`.
- **Decision:** System-tray icons are register-once SNI clients. A watcher restart (any QuickShell restart) empties the tray until the client apps restart — there is no re-scan. The KDE Connect icon requires `kdeconnect-indicator` (`kdeconnectd` exports no `StatusNotifierItem`); EasyEffects `--service-mode` and `blueman-applet` (GtkStatusIcon) can never appear. Tray renderers must not denylist `kdeconnect` while the indicator is autostarted.
- **Decision:** Battery runtime telemetry comes from `Quickshell.Services.UPower` only (`UPower.displayDevice` on the system bus: `energy`, `energyCapacity`, `changeRate`, `timeToFull`). Extends rule 3's sysfs-inotify ban: no `FileView` on `/sys`, no coalescing `Timer` (polling by another name). `UPowerDevice.isLaptopBattery` matches both the synthetic `DisplayDevice` aggregate and the real pack — always source `displayDevice` (never null, no enumeration race). Hover readout is an in-bar glyph↔text swap; the bar surface is never widened for tooltips.

### ADR-043: Shared Media Backend, Solid-Mode Existence Watches & No Destructive Signals
- **Decision:** All MPRIS/music/cava telemetry lives in root `MusicState.qml` (pragma Singleton). `TopBar.qml`/`SideBar.qml` are presentation-only and alias it (`property var musicData: MusicState.musicData`, …). No bar may own `playerctl --follow`, `music_info.sh`, json `FileView`, `cava`, or media timers — exactly one of each globally, independent of bar visibility. UI files are never merged for backend sharing.
- **Decision:** Marker-file `FileView`s (`wallpaper_killed`, `gaming_mode`) must pair `watchChanges` with `onFileChanged: { reload(); updateSolidMode(); }`. Directory-watch fires the signal on create/delete but the buffer stays stale without an explicit reload (quickshell `fileview.cpp`: `onWatchedDirectoryChanged` only emits; `powerProfileWatcher` already had the correct pattern). Without this, runtime state flips never propagate.
- **Decision:** Never `pkill -HUP wezterm-gui` (or any terminal) to "reload" config — SIGHUP terminates it and kills every pane. Wezterm hot-reloads on config mtime; `touch` the color/config files instead.

### ADR-044: Shared Coffee State, wpctl-Only Volume Writes & Reload Orphan Reaping
- **Decision:** Coffee mode state lives only in `SysData.coffeeActive` (synced from `state.json`); all trays read it, all writes go through `SysData.setCoffee()`. No widget may own a parallel coffee FileView.
- **Decision:** All volume writes go through `wpctl` (`set-mute`/`set-volume` on `@DEFAULT_AUDIO_SINK@`, mirroring `osd.sh` incl. unmute-on-raise and 100% cap). Native `sink.audio.*` writes silently no-op on stale nodes with no detectable failure — Pipewire stays read-only for display. `toggle volume` targets nothing (no such widget); volume clicks open the battery popup.
- **Decision:** Every QML-owned persistent `Process` gets explicit stops in `Component.onDestruction` — engine reload does not reliably SIGTERM children, orphaning one set per reload (observed 8× `playerctl --follow` at PPID 1). Verified: repeated `forceReload` holds exactly the live set, zero orphans.
- **Decision:** Battery direction comes only from `UPower.onBattery`. `timeToFull` is 0 whenever UPower can't estimate — branching on it runs discharge math while charging ("25h on AC"). AC without active fill, and any estimate over 10h, displays `"AC"`; pill text clamps at 11:59.
- **Decision:** After editing, verify non-ASCII string literals (nerd glyphs, CJK) with `hexdump` — tool output renders them invisibly and they can be silently dropped to `""`, producing blank-but-laid-out widgets.

### ADR-045: No Positioning Against Animating Geometry, Orphan Reaping & OOM Guard
- **Decision (revert lesson):** Never offset layout against live height animations (`childrenRect`/implicitHeight bindings driving anchors). The offset recomputes mid-animation and fights the layout's own tweens — jitter, shadows, drift. Workspace capsule stays locked at true center; optical balance is achieved by content design, not runtime shifting.
- **Decision:** `qs_manager.sh` brutal paths (`reload`, quickshell toggle) reap only PPID-1 strays of quickshell-spawned followers (exact full-command patterns). Live children and clipboard owners are never matched.
- **Decision:** `services.earlyoom` (`freeMemThreshold=5`, `freeSwapThreshold=100`, avoid compositor/shell) is the freeze guard: 23GB swap means the kernel OOM never fires in time under thrash; userspace must SIGTERM the hog at <5% available. macOS (compressed memory + Jetsam) and Windows (compression + app lifecycle kills) both ship such guards; desktop Linux/NixOS does not by default.

### ADR-046: Toggle-Effect Ordering, Native Model Signals, Boot-Critical Reads
- **Decision:** Toggleable tray adornments (coffee) render LAST so their appearance never displaces stable icons. Same rule both trays.
- **Decision:** Plain Hyprland binds cannot require "both Alts" (pressed Alt counts toward the mod mask) — deliberate chords add a real modifier (CTRL), documented inline. Never work around with submaps/timers.
- **Decision:** Cold-start model sync uses the backend's own change signals (`Hyprland.workspaces/toplevels.valuesChanged`), never deferred timers. One-shot timers are polling with a nicer name when the event source exists.
- **Decision:** Boot-critical `FileView`s (settings.json) use `blockLoading: true` so first-frame bindings see real values. Async-first-read leaves defaults live (wrong bar flashes) until load lands.

### ADR-047: Spread Layout, Persistent Tray Presence & Sequenced Handoffs
- **Decision:** Sidebar uses spread layout (top cluster top-pinned, bottom cluster bottom-pinned, CAVA floats in the void) — never offset against animating geometry, never center-lock mismatched clusters.
- **Decision:** Toggleable tray adornments are always rendered (dimmed when off, click toggles both ways) — zero layout shift, standard tray UX. A true SNI coffee is impossible without an external daemon (quickshell `SystemTrayItem` is host-only, `isCreatable: false`); rejected to avoid a new resident process.
- **Decision:** Bar position switches sequence (incoming reserves first, outgoing releases after grace) so edge motion reads correctly. All `FileView`-watched runtime flags (`rec_pid` included) pair `watchChanges` with `onFileChanged: reload()`.

### ADR-048: Mode-Specific Toggles, Full Template Substitution & Glyph Hygiene
- **Decision:** Mode indicators integrate into an existing host pill (coffee stacked inside battery, on only while active) — never inside shared trays/flows where toggling displaces stable icons. Sidebar carries no music UI at all (TopBar + MusicState own it).
- **Decision:** Every theme template placeholder must be substituted in EVERY mode (`--neutral` included). Raw `{{...}}` in live Qt/GTK configs produces unreadable apps.
- **Decision:** Non-ASCII literals (nerd glyphs) are byte-patched (`python3` `\uf0f4`) and hexdump-verified — never retyped through the editor.

### ADR-049: Lockscreen Fail-Fast, Single-Flight Spawn & Single Idle Authority
- **Decision:** A lock that isn't confirmed within 5s is a failed lock: `Lock.qml` quits loudly (`Qt.exit(1)`) instead of idling invisible with PAM waiting. Silent stuck locks poisoned `is_locked` and swallowed every future attempt.
- **Decision:** `cmd_lock` is single-flight (non-blocking flock) — concurrent triggers must serialize, never double-spawn. The flock mutex and fd 9 are explicitly released before `exec hyprlock` so the lock guard is never leaked to children. Strays are defined strictly (Lock.qml alive + session unlocked + older than 45s) and reaped before spawning. Lock-state checks match real quickshell binaries only, never cmdline mentions.
- **Decision:** Hyprland's `hypridle` daemon is the sole authoritative idle manager. Duplicate QuickShell `Idle.qml` / `Dim.qml` components are deleted to eliminate competing DPMS calls and unrecoverable black screens.

### ADR-050: Multi-Monitor Responsive Bounds & Active Screen Tracking
- **Decision:** All QuickShell popup geometries must be responsively clamped against active screen bounds in [`WindowRegistry.js`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/WindowRegistry.js) (`maxAllowedW = mw * 0.96`, `maxAllowedH = mh * 0.94`) and edge-clamped (`x = Math.max(8, Math.min(x, mw - fw - 8))`). Prevents off-screen clipping across diverse monitor resolutions (e.g., 1080p, 1440p, 4K) or scaling factors.
- **Decision:** Master overlay popup positioning in [`Main.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/Main.qml) dynamically tracks Hyprland's focused monitor (`syncActiveScreen()`) upon widget trigger, ensuring popups open on whichever display is currently focused.
- **Decision:** High-density popup lists (such as display resolutions in `MonitorPopup.qml`) must be wrapped in a bounded, momentum-scrolling `Flickable` with mouse-wheel and keyboard navigation, rather than expanding layouts that push critical action controls off-screen.

### ADR-051: Unified Theme Color SSOT & Global Media Color Indexing
- **Decision:** `~/.cache/theme/colors.json` generated by [`wallust/generate.sh`](file:///home/realdhiru/nix/dotfiles/wallust/generate.sh) is the sole single source of truth for desktop color tokens, ANSI 16 palette, cursor, selection, and UI accents in both neutral and dynamic modes. Applications supporting JSON parsing (such as WezTerm via `wezterm.json_parse()`) read `colors.json` directly, eliminating redundant per-application template files.
- **Terminal Visibility Mode:** `Super + L` preserves that generated palette and changes only Foot/Alacritty background opacity (`0.30` normally, `0.60` in QuickShell visibility mode). The toggle reloads both terminals, and later Wallust runs preserve the selected opacity.

### ADR-052: Open-Set Wallpaper Color Classification & Soft OKLCH Histogram Engine
- **Decision:** Wallpaper color classification uses a soft OKLCH histogram mass voting model combined with an open-set `ThemeRegistry` in Ottosson Oklab space (`classify.py`, `registry.py`, `sort.py`, `cli.py`, `eval.py`). Replaces brittle Cartesian vector means with continuous histogram mass distributions to eliminate complementary color cancellation and accent speck over-weighting.
- **Rules:**
  - **Color Representation & Histogram Voting:** 48x48 BOX downsample -> linear RGB -> Oklab -> OKLCH ($L, C, h^\circ$). Continuous 18 circular hue bins ($20^\circ$ each) with linear interpolation between adjacent bins, weighted by pixel chroma $C$.
  - **Chromatic Mass Gating:** Enforce strict $\ge 12\%$ chromatic mass threshold ($C \ge 0.030$). Low-chroma images route to `Dark`, `Light`, or `Monochrome` without letting minute high-contrast specks (<12% area) distort whole-image classification.
  - **Open-Set Discovery Pipeline:** 7D descriptor: mean $(L, a, b)$ + prominent chromatic mode $(L, a, b)$ + mean $C$. Novel wallpapers outside theme acceptance radii accumulate in `ThemeRegistry.pending` for agglomerative promotion into new aesthetic categories.
  - **Sub-Millisecond Performance:** Post-decode classification executes in $<1\text{ms}$ ($0.33\text{ms}$ average) using vectorized NumPy array math without iterative clustering overhead.

### ADR-053: Proprietary Electron GUI Packaging via Local FHS Wrapper
- **Decision:** macOS-only nixpkgs packages (e.g. `pkgs.chatgpt`) must never be added to `systemPackages`. Linux-only GUI apps shipped only as `.deb`/`.rpm` (official ChatGPT/Codex desktop) are packaged via `fetchurl` (pinned sha256) → `dpkg-deb -x` → `buildFHSEnv` wrapping the raw bundled Chromium binary, plus a merge of the real `.desktop`/icon.
- **Placement (superseding the original in-tree location):** The package now lives in a **standalone, publishable flake at `~/Projects/codex-flake`** (own git repo: `flake.nix`, `pkgs/chatgpt.nix`, `nixosModules.default`, `overlays.default`, README/LICENSE). `~/nix` consumes it as a flake input (`chatgpt.url = "path:..."`, `inputs.nixpkgs.follows = "nixpkgs"`) and pulls the overlay via `inputs.chatgpt.overlays.default`. This keeps a single source of truth and lets the package be shared/versioned independently of the personal config. On publish, the input URL switches to `github:Realdhiru/codex-flake`.
- **Wayland (runtime note):** OpenAI's Linux build is a custom Chromium "owl" runtime (not stock Electron). `ELECTRON_OZONE_PLATFORM_HINT` is a no-op for that runtime; native Wayland is forced with the raw Chromium switch `--ozone-platform=wayland` via a small launcher script inside the derivation. `NIXOS_OZONE_WL=1` (Electron-specific) does not affect this app.
- **Rationale:** No nixpkgs source package exists and upstream offers no AppImage; FHS env resolves all `Depends` libs without polluting system packages. A separate flake (vs. an in-tree `pkgs/*.nix`) makes it reusable by other NixOS users and independently maintained.

### ADR-054: Dynamic Window-Margin Popup Positioning & Inset Derivation
- **Decision:** QuickShell popup geometries in [`WindowRegistry.js`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/WindowRegistry.js) must never hardcode arbitrary margin values (e.g. `mr: 4`, `mx: 5`). Outer margins are dynamically derived from Hyprland's single source of truth: [`appearance.lua`](file:///home/realdhiru/nix/dotfiles/hypr/appearance.lua) (`gaps_out`).
- **Architecture:**
  - [`Config.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/Config.qml) monitors `appearance.lua` with a native `FileView`, dynamically updating `Config.gapsOut` via live inotify without restarting daemons.
  - [`WindowRegistry.js`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/WindowRegistry.js) derives the usable workspace insets based on active bar state (`usableTop`, `usableBottom`, `usableLeft`, `usableRight`), ensuring all popups (`battery`, `network`, `music`, `calendar`, `monitors`) strictly respect and align with the outer boundaries of tiled Hyprland windows in both Top Bar and Left Bar modes.

### ADR-055: Fastfetch-Only Terminal Font Scaling
- **Decision:** The Fastfetch launch binding may override Alacritty's font size per window, leaving normal terminal windows and the built-in NixOS logo unchanged. Lowering terminal font size scales the logo and information together; Fastfetch's built-in ASCII logo has no independent scale control.
- **OpenCode runtime note:** OpenCode's `system` theme uses terminal colors, but the installed 1.18.34 TUI exposes no supported live palette re-query. Keep its selected `system` theme; palette refresh requires upstream support or restarting the TUI.

### ADR-056: Super + External Keyboard Knob Scrolling
- **Decision:** The knob emits volume-up/down key events. Hyprland binds those events with Super held to `ydotool` wheel injection; without Super, the existing volume controls remain unchanged.
- **Collision fix:** Injected wheel events initially matched the existing Super + mouse-wheel zoom binds. Those binds now exclude Hyprland's virtual pointer device (`ydotoold-virtual-device-1`), preserving zoom on physical pointers while allowing knob scroll events to reach the focused app.

### ADR-057: Display Shader Ownership Split
- **Decision:** `hyprsunset` owns temperature and gamma through the hardware CTM/LUT. Hyprland's single `decoration:screen_shader` slot owns saturation, paper grain, and CRT curvature together.
- **Reason:** These are independent mechanisms, and Hyprland supports one active screen shader. New effects must preserve the ownership split rather than replacing an unrelated effect.

### ADR-058: KDE Connect Input on Hyprland
- **Decision:** Keep the small `hypr-kdeconnect-portal` backend while the packaged Hyprland portal lacks RemoteDesktop with `ConnectToEIS`. Route only RemoteDesktop to it; retain Hyprland and GTK for other portal interfaces.
- **Input paths:** Mousepad and presentation control use the RemoteDesktop portal. Drawing-tablet mode uses KDE Connect's digitizer and `/dev/uinput`, with KDE Connect's udev rules and the existing `uinput` group access.
- **Removal lesson:** The per-user portal files already selected `hypr-kdeconnect`, but the backend package had been removed and the NixOS portal config lacked that route. Keep these aligned until upstream support is present in the active Nixpkgs version.

### ADR-059: Native Touchpad Gesture Bindings
- **Decision:** Use Hyprland's built-in Lua gestures for workspace swipes and Super-modified pinch zoom. Pinch zoom uses a two-finger `pinch` gesture callback table (`start`, `update`, `end`): spreading fingers zooms in continuously proportional to finger distance; pinching inward even slightly immediately triggers `zoom_out()` to smoothly snap back to $1.0\times$. Mouse-wheel zoom retains discrete step-in/reset behavior. No gesture daemon or external plugin is needed.
- **Workspace behavior:** Enable `gestures.workspace_swipe_forever` so a single long swipe can continue past the adjacent workspace.

### ADR-060: Saved Wi-Fi Internet Auto-Failover
- **Decision:** NetworkManager monitors upstream connectivity using periodic HTTP status checks (`settings.connectivity.uri`, 30s). When connectivity drops to `LIMITED` or `NONE`, a dispatcher script searches currently broadcasting SSIDs against previously saved 802.11 profiles and switches to the strongest saved network.
- **Flapping prevention:** A 25-second cooldown timestamp is enforced in `/run/nm-wifi-failover/last_switch` to prevent rapid connection switching during transient drops.

### ADR-061: Bar Layer Reservation and Window Gaps
- **Decision:** TopBar and SideBar reserve their content dimensions (`barHeight`/`barThickness`) but exclude the visual edge margin. Hyprland's configured `gaps_out` supplies the gap around the bar footprint once, without overlapping the bar or adding a second margin.
- **Popup geometry:** `WindowRegistry.js` derives usable bounds from the bar footprint plus `gaps_out`, matching tiled windows in both bar orientations.

### ADR-062: Claude Desktop Packaging
- **Decision:** Keep the official Linux `.deb` packaging in the separate public `Realdhiru/claude-desktop-nix` flake, with a pinned version/hash, FHS runtime, native Wayland launcher, and build-verified automated update PRs.
- **System use:** Claude Desktop was removed from this system's inputs and packages at the user's request; the standalone repository remains published and maintained.
- **Cowork:** The repo keeps QEMU, OVMF, and `virtiofsd` in an optional package variant to avoid that dependency closure for the default package.

### ADR-063: Wallpaper Favorites Subsystem & Persistent Storage
- **Decision:** Favorite wallpapers are tracked in `$HOME/.local/share/wallpaper_favorites.txt` as canonical filepaths, toggled via `wallpaper.sh fav` (`SUPER + SHIFT + \`), and displayed under a dedicated "Favorites" tab in [`WallpaperPicker.qml`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/wallpaper/WallpaperPicker.qml).
- **Rationale:** Storing favorites in `$XDG_DATA_HOME` (`~/.local/share/`) prevents data loss during cache purges (`~/.cache/` cleans).
- **IPC & Synchronization:** QuickShell integrates a native `FileView` watching the file via inotify (`watchChanges: true`), immediately updating `favoritesProxyModel` in real time with zero polling loops or subprocess forks.

### ADR-064: Native PipeWire 10-Band Equalizer & EasyEffects Purge
- **Decision:** Replace EasyEffects user-service daemon entirely with PipeWire's built-in `libpipewire-module-filter-chain` declared in [`home.nix`](file:///home/realdhiru/nix/home.nix) (`~/.config/pipewire/pipewire.conf.d/99-equalizer-sink.conf`).
- **Rationale:** EasyEffects consumed ~150MB RSS, 46MB swap, 19 background threads, and frequent CPU wakeups just to apply static biquad audio filters. PipeWire's filter-chain runs directly inside the C audio server data-loop with 0MB additional memory and zero subshell forks.
- **Routing & Device Handover:** The filter chain exposes a virtual sink `effect_input.eq10` with session/driver priority 2200 and a passive playback node `effect_output.eq10`. Applications route to the equalizer by default, while WirePlumber automatically forwards the passive playback stream to the highest-priority physical output. All external physical output nodes (Bluetooth `~bluez_output.*`, USB DAC `~alsa_output.*usb.*`, Wired Headphones `~alsa_output.*Headphones.*`, and Headsets `~alsa_output.*headset.*`) are configured with `priority.session = 2150` and `priority.driver = 2150` in `51-device-autoswitch.conf`. Because `effect_input.eq10` (2200) strictly outranks all physical sinks, applications never bypass the 10-band equalizer, and HDMI/external monitor audio remains fully functional via dynamic jack detection (`haveAvailableRoutes`).
- **Multi-Output Audio Broadcast Mode (`SUPER + CTRL + V`):** Handled via [`toggle_multi_sink.sh`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/toggle_multi_sink.sh). Unlinks internal laptop speakers and fans out the equalizer output (`effect_output.eq10`) across all active external outputs (Bluetooth + Wired) simultaneously via sub-2ms native `pw-link` graph connections. Includes automatic Bluetooth latency compensation: dynamically inspects `bluez_output.*` hardware buffer delay (`pw-cli enum-params <id> Latency maxNs`) and inserts a transient, zero-CPU `pw-loopback` delay service (`pw-wired-delay`) on the wired channel so physical earphones match Bluetooth earbuds without audio echo or drift. Unlinks and tears down the delay node cleanly upon toggling OFF. Detailed architectural blueprint and cross-distro portability guide documented in [`docs/multi_output_audio.md`](file:///home/realdhiru/nix/docs/multi_output_audio.md).
- **Runtime Control & Zero-Python Hot Path:** Dynamic equalizer slider changes in QuickShell execute via instant POSIX commands (`pw-cli s <id> Props '{ "params": [ "eq_band_<idx>:Gain", <val> ] }'`). Python was permanently purged from the equalizer hot path.

### ADR-065: Flake Self-Hosting for Upstream Fast-Moving Packages
- **Decision:** Fast-moving binary applications (such as Zen Browser and ChatGPT / Codex) must be sourced from user-maintained flake repositories (`Realdhiru/zen-browser-flake`, `Realdhiru/codex-flake`) rather than third-party unpinned community flakes.
- **Rationale:** Upstream binary releases frequently re-release tarballs with identical version tags, changing the fixed-output derivation hash and immediately breaking NixOS system rebuilds. Self-hosted flakes isolate system rebuilds from upstream hash thrashing and allow deterministic lockfile synchronization.

### ADR-066: Intel GPU Ring Protection & Compositor Framebuffer Thrashing Safeguard
- **Decision:** All wallpaper mode toggles, desktop glass/solid transitions, and daemon lifecycle scripts (`wallpaper.sh`, `ensure_awww.sh`, `watcher.sh`) must enforce serialization and minimum debounce pacing (>1.5s).
- **Rationale:** Rapid destruction and re-allocation of 2.8K framebuffers with Kawase blur passes overwhelms the Intel `rcs0` execution ring. When the GuC reset times out, the Aquamarine DRM page-flip handler fails an assertion in `CHyprOpenGLImpl::begin` (`assertImpl -> abort -> SIGABRT`), causing Hyprland to crash and log out into safe mode. Visual operations must be paced to protect GPU ring-buffer stability.

### ADR-067: Emoji & Nerd Font Glyph Fuzzy Picker & Tab Toggling
- **Decision:** Implement a unified desktop fuzzy picker for emojis and Nerd Font glyphs using `fuzzel --dmenu` integrated into [`fuzzel_menu.sh`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/fuzzel_menu.sh), triggered via a single Hyprland keybind (`SUPER + .`).
- **Rationale:** Zero-overhead, compiled C Wayland client (`fuzzel`) eliminates heavy Electron or Python-based character maps. Database lookups run via single-pass POSIX `awk`, filtering 3,773 Unicode 15.1 emojis and 10,386 Nerd Font v3 symbols in <3ms.
- **In-Menu Tab Mode Switching:** Fuzzel configures `--override="key-bindings.execute-or-next=none"` and `--override="key-bindings.custom-1=Tab"`. Pressing `Tab` exits with code 10, allowing the caller shell loop in `fuzzel_menu.sh` to seamlessly hot-toggle between Emoji and Glyph modes without window dismissal or flickering.
- **Data Architecture:** Canonical database files reside under `dotfiles/hypr/assets/` (`emoji.db` and `glyph.db`) and are mirrored in `~/Projects/` and `~/.config/hypr/assets/`. Selected characters are immediately copied to Wayland clipboard using `wl-copy --type text/plain;charset=utf-8` followed by concise notification cues.

### ADR-068: Obsidian Native Integration & Dotfiles Knowledge Brain Vault
- **Decision:** Install Obsidian declaratively via `pkgs.obsidian` in `modules/system/packages.nix` without custom wrapper layers or redundant CLI flags. Maintain the system's central second-brain knowledge graph vault in `~/nix/docs`.
- **Rationale:** Upstream Nixpkgs packages Obsidian with an Electron wrapper that automatically checks for `NIXOS_OZONE_WL` and `WAYLAND_DISPLAY`, appending `--ozone-platform=wayland --enable-wayland-ime=true --wayland-text-input-version=3`. Because `hosts/nixos/system.nix` sets `NIXOS_OZONE_WL = "1"`, Obsidian natively binds to Wayland with kinetic scrolling and IME support with zero wrapper maintenance.
- **Glass Theming:** Scoped with opacity `0.65` in `dotfiles/hypr/rules.lua` matching the system-wide glass token hierarchy.

### ADR-069: Declarative Wine Leftover Janitor (`gameclean`)
- **Decision:** Wine/Proton/Lutris junk cleanup ships as a Nix-distributed binary (`pkgs/gameclean/gameclean.py` + `pkgs/gameclean.nix` derivation, registered via the flake overlay and exposed on system `PATH` by `modules/system/gaming.nix`) with its operational doc in `docs/gameclean.md` — not as an ad-hoc `~/.local/bin` script.
- **Rationale:** Wine games scatter files across five locations (game dir, `~/Games/prefixes`, shared umu/Proton prefix, `~/.cache` caches, `~/.local/share/lutris/games/*.yml`), so manual uninstall cleanup is error-prone and drifts. Packaging in-repo makes the janitor reproducible, versioned, and available on every machine the flake deploys to.
- **Safety Model:** Preview-only by default; `gameclean -y` deletes. Working titles are protected by building the referenced `prefix:`/`exe:` set from every Lutris `.yml` first — only true orphans (unreferenced prefixes, broken entries, umu `Temp`/shadercache, `~/.cache` game caches) are flagged.
- **Zero-Python Hot-Path Scope:** `gameclean` is an interactive, manually invoked janitor — not a desktop hot path — so the Python ban (see above) does not apply; no polling daemons or keybind handlers invoke it.
- **Implementation update (2026-11-08):** The shipped implementation is `pkgs/gameclean/gameclean.sh` (Bash with coreutils/gawk), not the historical `gameclean.py` path. `-y` refuses the whole pass when unreferenced or stray prefixes are present unless `--include-unmanaged-prefixes` is supplied; see ADR-085.

### ADR-070: Web Apps Hardware Video Acceleration & Window Glass Hierarchy
- **Decision:** All present and future Brave web apps and browser windows must receive native VA-API zero-copy hardware acceleration via user wrapper `~/.local/bin/brave` injecting `--use-gl=angle --use-angle=gl --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations --enable-zero-copy "$@"`.
- **Rationale:** Nixpkgs' default Brave derivation uses `makeShellWrapper` which does not load `~/.config/brave-flags.conf`. Injecting flags via `~/.local/bin/brave` (preceding system paths in `$PATH`) ensures all browser instances and PWAs offload 4K VP9/AV1 decoding to Intel Iris Xe with zero dropped frames.
- **Download Bubble Suppression:** Chromium's detached Download Bubble partial-view popups fall back to anchor `(0, 0)` in `--app` mode, causing popups to render offscreen at negative coordinates over the system bar. `~/.local/bin/brave` dynamically enforces `download_bubble.partial_view_enabled = false` across all profile preferences, keeping downloads cleanly in-window without out-of-screen anchor glitches.
- **Window Opacity Hierarchy:**
  - Video streaming (YouTube): strictly locked to solid opacity (`opacity = "1.0 override 1.0 override"`) and `idle_inhibit = "focus"` in [`rules.lua`](file:///home/realdhiru/nix/dotfiles/hypr/rules.lua) to eliminate GPU Kawase blur thrashing over high-framerate 4K video.
  - Messaging & Communications (WhatsApp Web): kept solid (`1.0`) without translucency.
  - Text & Productivity PWAs (Notion, Claude, ChatGPT, To-Do, Monkeytype): styled with unified glass translucency (`0.57`).

### ADR-071: QuickShell Timer Wake-Up Alarm Architecture
- **Decision:** The QuickShell timer alarm uses a high-decibel, high-penetration synthesized acoustic asset ([`alarm_beep.wav`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/quickshell/quickactions/sounds/alarm_beep.wav), 950Hz/1400Hz alternating tone at 2.5x gain) cycling every 1.0s via `pw-play` until explicitly dismissed.
- **Dismissal Mechanism:** Dismissal is anchored strictly to clicking the prominent center button on the auto-revealed popup or allowing the 3-minute hard failsafe auto-silence timeout (`alarmSafetyTimeout`) to expire. Wayland layer-shell keyboard grabbing hooks and shortcut overrides were purged to prevent unwanted input stealing and compositor state bloat.

### ADR-072: Input-Addressed Store Architecture with Flake Lock Pinning over CA-Derivations
- **Decision:** Retain the default Input-Addressed (IA / extensional) Nix store model backed by strictly pinned Flake inputs (`flake.lock`), rejecting experimental Content-Addressed (CA / intensional) derivations (`ca-derivations`).
- **Rationale:** Academic and empirical literature (Dolstra 2005, Zwinger 2025, Lix RFD 815) proves that while CA prevents multi-tenant store poisoning, it introduces the severe "Two Glibcs Problem" (Equivalence Class Collisions) where binary outputs built against subtle variations in dependencies conflict and crash. Resolving this requires secondary binary hash rewriting, which mathematically relies on the axioms $P_{\text{suff}} \land P_{\text{enum}} \land P_{\text{len}}$. Because $P_{\text{enum}}$ fails on compressed binaries or embedded bytecode tables, hash rewriting risks corrupting outputs. On a single-tenant workstation, Flake lockfile pinning provides absolute build environment determinism without any risk of binary corruption.
- **Related Theoretical Documentation:** Formally specified in [`Content-Addressing, Trust, and Equivalence Classes`](file:///home/realdhiru/Projects/Vault/nix-brain/03%20-%20Nix%20Fundamentals/Content-Addressing,%20Trust,%20and%20Equivalence%20Classes.md) and [`Formal Reference Tracking, Closure Invariants, and Store Path Calculus`](file:///home/realdhiru/Projects/Vault/nix-brain/03%20-%20Nix%20Fundamentals/Formal%20Reference%20Tracking%20and%20Closure%20Invariants.md).

### ADR-073: Cross-Platform Systems & Alternative Operating System Boundaries
- **Decision:** Treat NixOS on bare-metal Linux as the primary reference tier; enforce structured cross-platform deployment models for non-NixOS Linux (Standalone Multi-User Daemon), macOS (`nix-darwin` with synthetic firmlinks), and Windows (WSL2 Hyper-V microVM via `nixos-wsl`). Native Win32 Nix is rejected.
- **Rationale:** Native Win32 lacks core POSIX primitives essential to Nix calculus: NTFS default case-insensitivity, lack of unprivileged namespaces, backslash/drive path syntax breaking the 32-character invariant, and PE/COFF dynamic library search fallback ("DLL Hell"). WSL2 provides 100% native Linux kernel and ext4 semantics. On macOS, APFS sealed system volume requires `/etc/synthetic.conf` firmlinks, while binary linking transitions to Mach-O (`install_name_tool`, `@rpath`, Apple Silicon ad-hoc `codesign`).
- **Related Theoretical Documentation:** Documented in [`Nix on Other Linux Distributions (Standalone Nix)`](file:///home/realdhiru/Projects/Vault/nix-brain/07%20-%20Cross-Platform%20&%20Alternative%20OS/Nix%20on%20Other%20Linux%20Distributions%20%28Standalone%20Nix%29.md), [`Nix on macOS and the nix-darwin Subsystem`](file:///home/realdhiru/Projects/Vault/nix-brain/07%20-%20Cross-Platform%20&%20Alternative%20OS/Nix%20on%20macOS%20and%20the%20nix-darwin%20Subsystem.md), and [`Nix on Windows and WSL Architecture`](file:///home/realdhiru/Projects/Vault/nix-brain/07%20-%20Cross-Platform%20&%20Alternative%20OS/Nix%20on%20Windows%20and%20WSL%20Architecture.md).

### ADR-074: Native WebRTC Echo-Cancellation & Microphone Denoising Architecture
- **Decision:** Implement native hardware microphone cleaning via `libpipewire-module-echo-cancel` with WebRTC DSP in PipeWire's processing graph (`xdg.configFile."pipewire/pipewire.conf.d/60-echo-cancel.conf"` in [`home.nix`](file:///home/realdhiru/nix/home.nix)).
- **Rationale:** The laptop's raw PDM pins (`Mic1`) are uncalibrated and muted, while the physical stereo array (`Mic2`) captures background acoustic noise and speaker feedback. Rather than running CPU-heavy third-party Python/Electron apps or standalone daemons (NoiseTorch/EasyEffects), PipeWire's built-in WebRTC module processes audio directly inside the real-time audio thread:
  - `capture.props`: Taps `alsa_input...HiFi__Mic2__source` as a passive source (`node.passive = true`).
  - `monitor.mode = true`: Subscribes directly to `effect_input.eq10:monitor` to subtract speaker playback and acoustic bleed in real-time.
  - `source.props`: Exposes `echo_cancel_source` at session/driver priority `2100`, establishing it as the default, clean, echo-cancelled, and noise-suppressed input for all applications with zero daemon overhead.

### ADR-075: QuickShell Shortcut Isolation & Model Reconciliation Invariant
- **Decision:** All `Shortcut` definitions within popup modules or secondary overlays MUST declare explicit visibility bounds (`enabled: window.visible && ...`). Furthermore, dynamic `ListModel`s updated by background pollers or state triggers must NEVER call `listModel.clear()` immediately before calling `syncModel()` or `append()`.
- **Rationale:** 
  - *Shortcut Leaking in Preloaded Components:* `Main.qml` preloads popup components into memory during startup with `visible: false`. In Qt Quick, a top-level `Shortcut` without an explicit `enabled` expression remains active application-wide regardless of item visibility or focus, intercepting keys (e.g. `Tab`, `Left`, `Right`) meant for active user applications.
  - *Repeater Destruction/Insertion Collision:* Calling `listModel.clear()` emits row removal signals, queuing asynchronous delegate destruction via `destroyObjectLater`. If `listModel.append()` or `syncModel()` immediately repopulates items within the exact same event loop cycle, Qt Quick's `QQuickRepeater::modelUpdated` and `initItem` attempt sibling stacking (`item->stackBefore(after)`). Looking up sibling positions in `parentPrivate->childItems` dereferences invalidated pointers, triggering a fatal `SIGSEGV` in Qt 6. In-place reconciliation via `syncModel()` (modifying existing items and appending only true additions) maintains model item stability with zero desync crashes.

### ADR-076: Scrolling Ribbon Focus Stability & Cursor Warp Suppression
- **Decision:** In [`scrolling.lua`](file:///home/realdhiru/nix/dotfiles/hypr/scrolling.lua), set `scrolling.follow_focus = 0` and eliminate programmatic `move (left_margin - post_x)` layout snapping in `sync_workspace_layout()` for multi-window ribbons. In [`misc.lua`](file:///home/realdhiru/nix/dotfiles/hypr/misc.lua), declare `cursor.no_warps = true`.
- **Rationale:** 
  - *Ribbon Snapping on Layer Shell / Sidebar Clicks:* Clicking on the Quickshell left sidebar or toggling side panels shifts focus to/from layer shell surfaces. With `follow_focus = 1` or forced position clamping in `sync_workspace_layout()`, Hyprland and Lua layout normalization forcibly re-snapped the continuous ribbon back to `left_margin`, destroying kinetic scroll position. Setting `follow_focus = 0` and preserving scrolled coordinates ensures the continuous ribbon remains strictly where the user positioned it.
  - *Erratic Mouse Focus Warping:* Default Hyprland cursor warping (`cursor:no_warps = false`) jumps the mouse pointer when compositor focus transitions across tiled columns or secondary widgets. Setting `cursor.no_warps = true` keeps the cursor stationary and predictable during focus switches and layout adjustments.

### ADR-077: Scrolling Layout Isolation & Dwindle Parity Guards
- **Decision:** In [`scrolling.lua`](file:///home/realdhiru/nix/dotfiles/hypr/scrolling.lua), centralize layout detection in `is_scrolling_layout(ws_id)` and guard all layout-specific dispatches (`inhibit_scroll`, `colresize`, and `move +/-col` across lifecycle hooks, window resize, ribbon scrolling, and workspace sync) so that scrolling layout dispatches only execute when the active workspace's layout is explicitly `"scrolling"`. Non-scrolling layouts (e.g. `dwindle`) fall back natively to standard compositor window resizing (`hl.dsp.window.resize`).
- **Rationale:** 
  - *Hyprland C++ Dispatcher Error Escalation:* In Hyprland's Lua plugin architecture, `hl.dispatch(hl.dsp.layout(...))` delegates to the compositor's active layout engine. When Hyprland is in `dwindle` mode (or any non-scrolling layout), unrecognized layout commands (such as `inhibit_scroll false` or `colresize`) trigger an uncatchable C++ runtime error (`=[C]:-1: Unknown dwindle layoutmsg...`) that bypasses Lua's `pcall` and manifests as an intrusive yellow compositor notification banner on every window or workspace event (`window.open`, `window.close`, `window.active`, `workspace.active`).
  - *Layout Parity Invariant:* Proactively checking `is_scrolling_layout(ws_id)` before emitting any scrolling layout message prevents invalid layout dispatch attempts at the root, completely eliminating runtime errors while allowing tandem resizing keybindings and mouse wheel actions to gracefully fall back to native window resizing in Dwindle mode.

### ADR-078: Power, Display, State, and Audio Ownership
- **Decision:** Keep TLP as the sole hardware profile writer. Power Saver retains the balanced platform profile; Balanced battery behavior remains locked. TLP's Intel GPU battery maximum is explicit at the hardware limit, and the NMI watchdog is documented as system-wide.
- **Decision:** Keep global USB autosuspend disabled because the webcam stability history contains no VID:PID. TLP mirrors that with `USB_AUTOSUSPEND=0`; do not narrow the workaround to an unidentified device.
- **Decision:** Use `$DESKTOP_STATE_DIR/monitors/intent.json` for saved display layout, mode, scale, transform, and placement. Power events choose refresh from Hyprland `availableModes`, update only the mode refresh, and never re-enable a disabled internal display.
- **Decision:** QuickShell reads persistent state through `Caching` paths. Network selection and WallpaperPicker use the canonical desktop state directory; Coffee runtime state remains untouched.
- **Decision:** FocusTime retains one-second database accounting but publishes live JSON on app changes or every 15 seconds. Battery audit samples every 60 seconds; per-app Wh is modeled from CPU time, not measured. CAVA runs only when its TopBar visualizer is visible and media is playing.
- **Decision:** Keep PipeWire and WirePlumber audio declarations together in `modules/home/audio.nix`, preserve the internal speaker keep-awake preference and A2DP stereo, and align karaoke defaults with `karaoke.sh`.
- **Decision:** Python remains available only for the user-managed external `auto_organize.py` calls; every call checks for `python3` and the script. The inline-code guard reports those exact exceptions and rejects other Python/Node commands.
- **Decision:** Set `/dev/uinput` to `0660` with the session ACL and remove broad `input` group membership because repository consumers use uaccess or uinput access. Keep hotspot UDP ports global because the NetworkManager shared interface has no deterministic name in the repository.
- **Decision:** `rebuild` builds the current tracked tree through a `git+file` flake reference, switches, health-checks, and rolls back on critical failure. It never stages or commits.

### ADR-079: Portable Host and Personal Configuration
- **Decision:** Discover NixOS configurations from complete `hosts/<host>/system.nix` and `hardware-configuration.nix` pairs. `nix run .#init-host -- <name>` detects hardware and creates missing host files without overwriting existing files. `user.nix` owns personal defaults; shared modules consume generated host facts instead of assuming Intel, ASUS, a battery, or a specific display.
- **Decision:** Keep the global USB autosuspend workaround unchanged while camera troubleshooting is deferred; derive the kernel argument and TLP setting from the same user workaround flag.
- **Decision:** Monitor controls read active outputs and advertised modes at runtime. The unused `settings.json` eDP-1 mode list was removed; the machine-specific connector and supported rates remain documented in `hosts/nixos/PERSONAL.md`.
- **Decision:** Keep TLP's exact passwordless profile commands in the power module and emit them only when host facts indicate a battery; keep audio recovery's narrow `modprobe` allowlist in the user module.
- **Decision:** The personal home directory is explicit in `user.nix` and consumed by both NixOS user creation and Home Manager paths, so changing the username does not silently keep `/home/realdhiru`.
- **Decision:** Home-managed Brave and OnlyOffice launchers resolve their executables from the selected Nix packages rather than absolute system-profile paths.

### ADR-080: Serialized AC Power Pipeline & Single-Flight Modeset
- **Decision:**
  1. Profile transitions in [`power.sh`](file:///home/realdhiru/nix/dotfiles/hypr/scripts/power.sh) acquire a bounded exclusive flock on `/run/user/$UID/desktop-power.lock` using dedicated file descriptor 7 while applying TLP and persisting profile state. They release it before calling `mode_ctl.sh`, avoiding inversion with the modes lock.
  2. Skip redundant `sudo tlp` execution when `$DESKTOP_STATE_DIR/power/applied` matches the requested profile.
  3. Reorder the transition pipeline: hardware TLP profile runs first invisibly; compositor appearance and modes run second with `MODE_CTL_NO_PROFILE=1` (preventing recursion) and `WALL_TRANSITION=none` (preventing wallpaper layer tearing); display refresh rate modeset runs last (`refresh_monitor.sh 7>&-`).
  4. A udev-triggered user timer coalesces power-supply events for 500ms before `power.sh auto` runs. Refresh and power application use bounded lock waits and compositor IPC timeouts.
- **Rationale:** Previously, plugging or unplugging the AC charger while in power-saver mode caused 3 distinct blinks, visual stutter, and seconds of lag. QuickShell's UPower watcher and the kernel udev rule both fired simultaneously at the moment of AC state change. `power.sh profile` called `mode_ctl.sh`, which in turn invoked `power.sh profile` again, running `sudo tlp` and `refresh_monitor.sh` twice. Furthermore, the hardware display modeset fired first, followed by compositor shader changes and wallpaper re-renders. Serializing the pipeline under flock, suppressing duplicate TLP runs, and deferring the hardware display modeset to the very end consolidates all visual adjustments into a single hardware refresh rate switch.

### ADR-081: Lazy QuickShell Widget Creation and Bounded Recovery
- **Decision:** Create cached QuickShell widgets only on first open; do not instantiate hidden widget windows at shell startup. Bound Hyprland and QuickShell IPC initiated by profile, mode, reload, and window-management scripts. Serialize QuickShell commands with an operation lock and keep a separate kernel flock held for the Shell.qml process lifetime. Restart `playerctld` on failure with a 3-start/60-second systemd limit so MPRIS interface crashes recover without hiding their logs.
- **Rationale:** Hidden widget instances ran their `Component.onCompleted` handlers and background helpers even when never opened. Unbounded synchronous IPC and overlapping power events were consistent contributors to stalls. A bounded restart recovers the observed `playerctld` crash while preventing a rapid restart loop.

### ADR-082: Optional Battery-First Balanced Policy
- **Decision:** `user.power.balancedBatteryFirst` defaults to `false`. When enabled, TLP uses `power` EPP, disables CPU boost on battery only, and caps Intel GPU battery frequency / boost to 1100 MHz; Power Saver, AC, platform profile, and default Balanced behavior are unchanged.
- **Rationale:** This exposes a lower-consumption Balanced variant without overriding the user's established responsiveness preference, avoiding the exponential power spike of driving Intel Iris Xe graphics past 1.1 GHz on battery.

### ADR-083: Retain FocusTime Samples on Database Failure
- **Decision:** FocusTime keeps buffered accounting records until every grouped insert and transaction commit succeeds. Failed flushes are logged and retried with the same records.
- **Rationale:** Draining the in-memory buffer before writes and ignoring SQLite errors could silently lose usage history. The transaction already provides atomicity; preserving the buffer closes the remaining loss path.

### ADR-084: Bound UI and Monitor IPC
- **Decision:** Scripted Hyprland and QuickShell IPC has finite deadlines, including widget-owned monitor and timer calls. State/settings/audio/layout/monitor/power locks have bounded acquisition; wallpaper replacement waits at most 30 seconds. Monitor mode selection remains outside compositor evals.
- **Rationale:** A blocked compositor socket or stale lock should fail that operation in bounded time instead of holding an event, reload, or widget action indefinitely. Failed requests remain visible through the caller's existing return handling or journal output.

### ADR-085: Require Explicit Opt-In for Unreferenced Prefix Deletion
- **Decision:** `gameclean -y` refuses the cleanup pass if unreferenced or stray prefixes are detected. Deleting those paths requires `--include-unmanaged-prefixes`; duplicate and nested candidates are counted and removed only once.
- **Rationale:** Absence from Lutris YAML does not prove that a prefix is unused; Steam, umu, and manual Wine setups may own it. The opt-in preserves the janitor feature while avoiding silent recursive deletion of unmanaged prefixes.

### ADR-086: Make Live Mode Self-Test Explicit
- **Decision:** `scripts/selftest-modes.sh` requires the explicit `--live` argument before it resets or transitions desktop modes. Its Hyprland wrapper resolves the external client through `env` so `timeout` runs an executable rather than a shell builtin.
- **Rationale:** The suite changes user runtime modes and must not be mistaken for a read-only diagnostic. The previous summary also claimed blocked-transition behavior while the assertions exercised atomic preemption.

### ADR-087: Bound Desktop Helper Work and Keep Generated Theme Data Out of Source
- **Decision:** Interactive audio clients have finite IPC deadlines, sink cycling is serialized, and FocusTime seeks atomically replace a single pending request consumed by one worker. Fuzzel colors are passed at launch from Wallust's cache palette; theme generation does not edit the tracked launcher config. Video-loop outputs are written to a same-directory temporary file and atomically renamed after successful encoding, with per-input batch failures reported without aborting later files.
- **Rationale:** A stuck user daemon should not hold a shortcut indefinitely, simultaneous audio transitions should not interleave, generated colors should not dirty source config, and an encoder failure should preserve an existing output instead of leaving a partial file.

### ADR-088: Pause Decorative Shell Marquees in Power Saver
- **Decision:** TopBar and Music title marquees use the same observed-profile animation gate as decorative widget loops. Recording and action-status indicators remain active.
- **Rationale:** Text motion is continuous display work with little value in Power Saver; keeping state indicators visible preserves useful feedback.

### ADR-089: Keep Home Manager Services With Their Owning Features
- **Decision:** `wallpaper.nix` owns wallpaper paths, the wallpaper symlink, and awww/mpvpaper user units; `quickshell.nix` owns the FocusTime unit; `audio.nix` owns the retained WirePlumber libcamera setting; `monitors.nix` and `desktop-state.nix` own their exported environment values. `desktop.nix` composes these modules and keeps general desktop application setup. System-level TLP policy remains in `modules/system/power.nix`.
- **Rationale:** Feature files remain the source of truth for their session state and services, while the generic Home Manager entry file stays focused on composition and application setup.

### ADR-090: Standalone BudsLink Flake Integration and Silent Health-Check Probe
- **Decision:** Package `budslink` as a standalone upstream flake (`budslink-flake`) under `~/Projects/flakes/budslink-flake` rather than polluting core nixpkgs overrides. Support OnePlus Nord Buds 3 alongside a generic BBK fallback for unlisted models, mapping direct hardware mode bytes (0x01 Noise Cancellation, 0x02 Off, 0x04 Transparency). Make the `rebuild()` post-switch `alacritty` health probe non-intrusive by launching with `--title "health-check-probe"` and routing it to a hidden, zero-opacity workspace (`special:silent`), preserving full Wayland EGL/i915 GPU hang verification without popping up visible windows.
- **Rationale:** Proprietary Bluetooth Low Energy (BLE) vendor GATT sockets are not exposed by standard desktop audio servers (PipeWire/WirePlumber). Maintaining BudsLink in a dedicated flake keeps the core rice minimal while providing automated weekly upstream sync via GitHub Actions. Flashing a terminal on-screen during routine rebuilds was visually disruptive, but headless tests fail to exercise the compositor window map/commit path that catches real GPU hangs. Routing the probe to an unmapped silent workspace satisfies both invariants.

### ADR-091: Modes Single Source of Truth Alignment and Boot Opacity Synchronization
- **Decision:** In `rules.lua`, `is_solid_mode()` strictly adheres to `modes.json` as the Single Source of Truth, querying the `state.json` fallback only when `modes.json` is missing or unreadable. `hl.on("window.open")` dynamically and symmetrically dispatches `prop = 'opaque'` as `'1'` when Solid Mode is active and `'unset'` when inactive. In `mode_ctl.sh`, the `apply` command passes `FORCE_APPLY=1` to guarantee active window properties and client configs (`alacritty-colors.toml`) synchronize with the computed mode on boot/reload without requiring a mode flip.
- **Rationale:** Previously, `is_solid_mode()` fell through to `state.json` even when `modes.json` reported `opacity_solid: false`, leading to stale state overriding canonical mode computation. Furthermore, `recompute_and_apply` in `mode_ctl.sh` gated compositor window properties and terminal opacity reloads strictly behind state value transitions (`solid_val != old_solid`), creating a cold-boot synchronization gap where `mode_ctl.sh apply` acted as a no-op if the persisted state matched baseline. Synchronizing windows symmetrically on open and executing `FORCE_APPLY=1` on explicit `apply` ensures natural, deterministic mode behavior across cold boots without artificial workarounds or duct tape.
