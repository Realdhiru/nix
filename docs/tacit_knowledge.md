# System & Workflow Tacit Knowledge Reference

## 1. Taste & Aesthetic Preferences

### Visual & Interactive Controls
- **Continuous Controls Over Discrete Presets:** Strong preference for continuous, responsive sliders (e.g., Night Light / Sunset Temperature, Gamma, Saturation) rather than rigid preset buttons. Sliders must be strictly bound to valid hardware/software ranges (e.g., Gamma clamped to $\le 100\%$, never arbitrary upper limits like $125\%$).
- **Connected UI Lifecycles:** Interactive controls cannot be visual-only facades. Sliders and toggles must manage daemon lifecycles directly (e.g., launching `hyprsunset` on slider interaction if inactive, terminating it when reset to defaults).
- **Keyboard Navigation Standard:** Custom desktop widgets must support native arrow-key navigation and keyboard focus traversal alongside mouse clicks.

### Layout Geometry & Proportions
- **Zero Dead/Empty Space:** Intense dislike for unused or unbalanced space. Cards, popups, and button rows must fill available dimensions proportionally. There must be no orphan vertical voids at card bottoms or uneven lateral padding.
- **Symmetry & Balanced Padding:** UI cards must look intentionally designed rather than like an unstyled checklist. Button columns, slider rails, and headers must maintain consistent alignment, relative widths, and unified visual rhythm.
- **Content-Derived Minimum Dimensions:** Widget geometry must be derived from non-negotiable text content rather than arbitrary fixed widths. In `TopBar.qml`, the music widget column width is anchored to `timeText.implicitWidth` minimum bounds so short song titles (e.g., `命盤`) never shrink the container or truncate timeline timestamps (`01:24 / 06:45`), while long titles marquee scroll inside the allocated space.

### Color Philosophy & Theming
- **Dynamic Wallpaper Derivation:** Hardcoded color values (hex or static color names) are strictly forbidden across UI widgets, terminals, and scripts. All colors must be dynamically extracted from the active wallpaper via Wallust.
- **Purge of Residual Defaults:** Leftover palette fallbacks (e.g., hardcoded Catppuccin sapphire, blue, peach, or maroon accents in `MusicPopup`, `NetworkPopup`, `BatteryPopup`, `CalendarPopup`, `FocusTimePopup`) are considered defects. Every accent, highlight, and surface must bind to dynamic tokens.
- **OLED Pitch-Black Authority:** The physical display is an ASUS 2.8K 120Hz OLED. True black means physical `#000000` (0.000 nits, 0 mA draw). Hyprland’s compositor root background is locked to `0x000000` (disabling Hyprland's default `0x111111` gray). When wallpaper processes are killed, the screen must drop to pure `#000000`.
- **Permanent Dark Mode Rule:** The global theme is permanently locked to dark mode (`saliencedark16`). Wallpaper switches must never trigger automatic light mode. Light mode is strictly manual via `settings.json` (`"themeMode": "light"`).
- **Deterministic Neutral Mode (`--neutral`):** On pitch-black or minimalist wallpapers, extraction algorithms generate false olive-green or muddy hue spikes from compression noise. The theme engine must execute a deterministic neutral bypass (`--neutral`) to generate an OLED black-and-ivory palette without color noise.
- **Terminal Legibility via Lch Extraction:** Terminal background must remain transparent while ANSI slots (`color0`–`color15`) are derived dynamically via `ansidark16` and `lchansi`. Standard ANSI semantic roles (red for errors, green for success) must remain distinct and readable against transparent backgrounds.
- **Visualizer Styling:** TopBar CAVA visualizer requires a vertical top-to-bottom gradient reflecting wallpaper accent tones, matching the status bar styling.

### Borders, Shadows & Glassmorphism
- **Frameless / Zero-Border Standard:** Artificial hairline borders, stroke wrappers, and rotating animated masks are banned across all QuickShell widgets (`borderWidth = 0`, `borderOpacity = 0.0` in `settings.json`). Adding unrequested borders or outlines is an immediate point of contention.
- **Hardware Kawase Blur:** Blur is enforced at the compositor level on all QuickShell surfaces via `rules.lua` matching namespaces `^(quickshell|qs-.*)$` with `ignore_alpha = 0.05`.
- **Anti-Bleed Layering:** Glass surfaces must prevent high-contrast wallpaper elements (sketches, linework, text) from showing through translucent cards. Popups must use a solid foundation layer (`root.base + effectivePopupOpacity`) behind translucent components to maintain contrast and legibility.

### Naming & Structural Conventions
- **Dynamic Semantic Tokens in QML:** Use dynamic tokens (`root.primary`, `root.base`, `Theme.colors.primary`) instead of legacy `mocha.*` names or literal color strings.
- **Centralized Settings Authority:** Visual and behavioral parameters across QuickShell must be defined in `settings.json` / `QUICKSHELL_SETTINGS.md`. Individual widget files must never hardcode localized styling or opacity overrides.
- **Modular Widget Architecture:** QuickShell widgets must remain self-contained with localized `Scaler.qml` and `Theme` adapters, eliminating brittle relative parent traversals (`import "../"`) that break when files are relocated.

---

## 2. Rejected Approaches & Why

### Tool & Subsystem Migrations
- **Matugen $\rightarrow$ Wallust:**
  - *Why Matugen was rejected:* Matugen (Material You algorithm) generates a tonal palette from a single dominant seed color. It failed to extract the diverse 16 ANSI colors present across complex wallpapers (neon, nature, anime), resulting in flat, repetitive, and muddy terminal schemes. It also leaked light-mode colors and produced false green spikes on dark backgrounds. Additionally, Matugen was tangled in a monolithic 220+ line `set_wallpaper.sh` script mixing daemon management with color generation.
  - *Why Wallust was chosen:* Native Rust binary using K-Means clustering in Lch colorspace (`lchansi` + `ansidark16`). Extracts distinct wallpaper colors mapped to standard terminal ANSI slots with contrast checks, and runs as an independent CLI engine emitting to `~/.cache/theme/`.
  - *Crucial Migration Lesson:* An earlier migration attempt broke the desktop because Wallust provides only 19 fixed slots (`color0`–`color15`, `bg`, `fg`, `cursor`), whereas the QML widgets depended on ~26 named Catppuccin roles from `MatugenColors.qml`. Any theming transition must preserve a semantic compatibility mapping layer (`Theme.qml`) to avoid breaking the shell.
- **Niri $\rightarrow$ Retained Hyprland:**
  - Tested running Niri (scrollable tiling compositor) as an alternative to Hyprland.
  - *Why rejected:* Incomplete keybinding parity, broken QuickShell layer surface protocols, lack of smooth touchpad gesture parity across native apps, and unnecessary configuration fragmentation. Reverted to Hyprland.
- **Rofi $\rightarrow$ Fuzzel:**
  - *Why Rofi was rejected:* Bloated configuration, poor scaling across HiDPI changes, and sluggish startup.
  - *Why Fuzzel was chosen:* Wayland-native, lightweight, instant startup, pixel-perfect frosted glass transparency, and reliable exact-string matching.
- **Flatpak $\rightarrow$ Rootless Podman + Distrobox (`deb-box`):**
  - *Why Flatpak was rejected:* Persistent background daemons, systemd service sprawl, permission issues, and lingering idle memory consumption.
  - *Why Distrobox was chosen:* Daemonless rootless Podman containers that run on demand, install standalone `.deb` packages via `distrobox-install-deb.sh`, export clean `.desktop` entries into Fuzzel, and shut down completely when closed (zero idle CPU/RAM overhead).
- **Periodic Bash Polling Loops in QML $\rightarrow$ Native C++ IPC:**
  - *Rejected:* Running periodic `Process` or `Timer` bash scripts (`workspaces.sh`, `colors_wait.sh`, `settings_wait.sh`, `update_wait.sh`, `wpctl`) inside QML.
  - *Why:* Caused fork storms (thousands of subprocesses per hour), CPU wakeups, and high battery draw.
  - *Enforced:* Native C++ event-driven IPC only (`Quickshell.Hyprland`, `Pipewire`, `FileWatcher`, `FileView`).

### Rejected Agent Proposals & Past Corrections
- **Hallucinated DSL Fields (`no_border` / `no_shadow`):** An agent once added `no_border = true` to `hl.window_rule` in `rules.lua` without checking `hl.lua` schema, breaking Hyprland configuration reloads. Global border size was already 0 in `appearance.lua`. Never add unverified parameters to DSL wrappers.
- **Premature Fixes Without Root-Cause Diagnosis:** Agents previously jumped into editing power scripts (`setPowerProfile.sh`, TLP) before presenting empirical evidence on what was actually causing performance issues (e.g., confusing thermal throttling with inverted EPP logic). The user requires root-cause isolation with command output before code is touched.
- **Automatic Wallpaper Pausing in Power Profiles:** An agent proposed pausing video wallpapers automatically in battery saver mode. Rejected because the user maintains manual keybind control over wallpaper processes and does not want automated profile interference.
- **AI-Generated Nix Configuration Bloat:** The user conducted extensive refactoring to strip unneeded AI bloat, deleting `memory.nix` (folding zram into `boot.nix`), removing unneeded packages (`nodejs`, `vscodium`, `zbar`, `wine`), and banning speculative helper daemons.

---

## 3. Workflow Expectations of an Agent

### Verification & Testing Discipline
- **Exit Code 0 is Not Proof of Completion:** Never declare a task complete merely because a QML file compiled or `quickshell ipc call main reloadTheme` returned exit code 0.
- **Visual Layout & Proportion Audit:** Before marking UI work done, verify content proportions, check that containers fill available space without voids, ensure buttons are symmetrical, and verify anti-bleed layering against high-contrast backgrounds.
- **The Cold-Start Verification Gate:** Widgets frequently appear fine on repeated opens because geometry is cached in memory. You must test the **FIRST open** immediately following a fresh `forceReload` or compositor restart. Cold-start reveals shape snaps, container resizing jumps, and uninitialized geometry.
- **Empirical System Measurement:** When modifying power, audio, or hardware configs, verify actual runtime state (e.g., `tlp-stat -p`, sysfs register reads, PipeWire node states), not just that a script completed cleanly.

### Reporting & Interaction Style
- **Evidence-Based Reporting:** Present concrete before-and-after evidence: configuration diffs, generated file contents (e.g., `wezterm-colors.lua`), sysfs values, or command outputs.
- **Strict Separation of Diagnosis from Fix Application:**
  1. Investigate read-only first.
  2. Present the diagnostic findings and root cause with proof.
  3. Propose the exact change.
  4. Apply the change only after validation.
- **Zero Unsolicited Scope Creep:** Do not modify unrelated files, adjust global keybindings, or introduce new decorative styling (borders, animations) unless explicitly requested.
- **Verify Schema and Precedent First:** Before using helper functions or configuration tables (e.g., `hl.window_rule`, `hl.exec_cmd`), grep the codebase for existing usages or read the underlying implementation (e.g., `hl.lua`). Never assume a field exists based on generic upstream documentation.
- **Communication Density ("Caveman Mode"):**
  - Zero filler, pleasantries, or generic conversational padding.
  - High semantic density, technical rigor, and concise bullet points.
  - Clickable markdown links with absolute paths (`file:///home/realdhiru/...`) and exact line numbers.
- **Manual Git Control:** Never execute `git add`, `git commit`, or `git push` automatically. The user stages, commits, and pushes all repository changes manually.

---

## 4. Architectural Decisions & Reasoning

### Hardware Authority & Power Management
- **Single Hardware Authority (TLP 1.9.1):** TLP is the sole manager of platform profiles, EPP, and ASPM (`power.nix`). In `asusd.ron`, `change_platform_profile_on_battery/on_ac` is locked to `false`. `asusd.service` exists solely to enforce the 80% battery charging ceiling (`charge_control_end_threshold = 80`).
- **Lid Switch Behavior:** `HandleLidSwitch = "ignore"` in `logind.conf`. Closing the laptop lid never suspends the machine; suspend is strictly manual (`Shift + Esc`).
- **Balanced Profile Integrity:** The Balanced battery profile (`balance_performance`, Turbo `1`, Platform Profile `balanced`, ASPM `powersupersave`) is empirically calibrated and locked against arbitrary changes.
- **Intel P-State EPP Quirk:** Writes to `/sys/devices/system/cpu/cpu*/power/energy_perf_bias` fail with `EBUSY` if the scaling governor is set to `performance`. `set_epp.sh` must switch governor to `powersave` immediately prior to applying EPP values.

### Declarative Symlinks & System Modularity
- **Out-of-Store Symlinks (`mkOutOfStoreSymlink`):** Configuration files in `dotfiles/` are linked out-of-store directly into `~/.config/`. This permits instant live edits and hot-reloads without running a full `nixos-rebuild` cycle for every script, QML widget, or styling token change.
- **Subsystem Decoupling:** Strict architectural boundaries exist between modules:
  - `dotfiles/wallust/`: Standalone color engine. Handles palette extraction, luminance calculations, and template generation. Zero UI dependencies.
  - `dotfiles/wallpaper/`: Background manager (`wallpaper.sh`). Manages daemons (`awww`, `mpvpaper`), directory watching, and thumbnail caching. Hands off to the color engine via an asynchronous call (`$THEME_ENGINE "$WALLPAPER" &`).
  - `dotfiles/hypr/scripts/quickshell/`: UI layer. Reads generated colors from `~/.cache/theme/colors.json` via native IPC and reloads on frame 0.
- **System Tray Relocation:** The system tray was intentionally removed from `TopBar.qml` and placed inside `BatteryPopup.qml`. This preserves TopBar minimalism (reserving space for dynamic workspace pills, CAVA visualizer, and clock) and consolidates tray icons with system controls (Hotspot, DND, volume, brightness, power profiles).
- **Single-Pass Popup Scaler:** Popup `Scaler` components must bind `currentWidth: Screen.width`. Passing device-pixel bounds (`Config.masterWidth`) causes double-scaling multiplication ($1.33 \times 1.33 = 1.77$), clipping content off-screen on HiDPI displays.
- **Host MIME Isolation for Containerized Apps:** Desktop entries exported from Distrobox containers via `distrobox-install-deb.sh` are sanitized to strip generic protocol handlers (`http`, `https`, `text/html`, which remain permanently locked to `brave-browser.desktop` in `home.nix`). Containerized apps cannot hijack default system associations.
- **Single-Radio Wi-Fi Hardware Constraint:** The ASUS Wi-Fi adapter has a single frequency synthesizer (`#channels <= 1`). It cannot maintain a simultaneous Wi-Fi station connection and Wi-Fi hotspot on 5 GHz DFS networks without connection drops. The hotspot setup is architected to share Ethernet/USB tethering over Wi-Fi.
- **Sonix FHD Webcam Loopback Pass-Through:** The webcam controller experiences USB babble crashes when non-native resolutions or MJPEG compression are requested. Fixed via `v4l2loopback` `/dev/video10` fed by an on-demand FFmpeg native YUYV pass-through, while WirePlumber's conflicting `libcamera` monitor is disabled (`50-disable-libcamera.conf`).

### Resolved & Completed Threads
- **Wallpaper Picker Multi-Level Sorting:** Completed. Reorganized the wallpaper picker widget to display GIFs first (sorted by dominant aesthetic color), static images second (sorted by dominant aesthetic color), and video wallpapers last (`getFileTypeRank` + HSL score band map).
- **Sunset / Night Light Widget Redesign:** Completed. UI layout overhauled to eliminate dead space, continuous slider controls, clamped gamma $\le 100\%$, and integrated daemon lifecycle control (`hyprsunset`).
- **Video Wallpaper Lockscreen Flicker:** Fixed. Eliminated 1-second flicker when locking during `mpvpaper` playback by utilizing a poster frame underlay beneath the lockscreen surface.
- **Spotify Lyrics Floating Window Rule:** Applied in [`dotfiles/hypr/rules.lua`](file:///home/realdhiru/nix/dotfiles/hypr/rules.lua) matching class `^(chromium-browser)$` and title `.*•.*` with `float = true`, `pin = true`, `size = {300, 95}`, and `opacity = "1.0 override 1.0 override"`, properly scoped from general chromium 0.85 opacity.

### In-Progress & Unresolved Threads
- None currently open.

---

## 5. Recurring Pain Points (Proactive Watchlist)

- **QuickShell Cold-Start Geometry Snaps:**
  - *Symptom:* Widgets appear properly proportioned on second or third open, but exhibit container clipping, uninitialized bounds, or shape snaps on the very first open after a reload.
  - *Mitigation:* Always verify frame-0 geometry, ensure explicit width/height bindings on root cards, and use two-phase layer dismissal (keeping `visible = true` while exit transitions run, setting `visible = false` only when opacity reaches 0).
- **Opacity Bleed Across Translucent Glass:**
  - *Symptom:* High-contrast wallpaper linework, sketches, or text bleed through semi-transparent cards, making UI text unreadable.
  - *Mitigation:* Ensure popup containers utilize a solid base background (`root.base + effectivePopupOpacity`) backed by hardware Kawase blur (`ignore_alpha = 0.05`).
- **Ghost Workspaces in TopBar:**
  - *Symptom:* TopBar continues to render empty workspace pills after windows are closed or moved rapidly across workspaces.
  - *Mitigation:* Cached JSON workspace state settles slower than QuickShell's C++ ObjectModel. Rely on live `Hyprland.toplevels` and `ws.toplevels.count` evaluated via `Qt.callLater`, dynamically tracking `Math.max(6, focusedId, maxOccupiedId)`.
- **False Palette Spikes on Dark/Monochrome Wallpapers:**
  - *Symptom:* Setting a pure black, minimalist, or dark wallpaper causes color extraction tools to amplify compression artifacts, resulting in harsh olive-green or bright blue accent spikes across the desktop.
  - *Mitigation:* Route dark/black wallpapers through Wallust's deterministic neutral bypass (`--neutral`) and ensure fallback paths do not revert to hardcoded Catppuccin defaults.
- **CPU Wakeups from Subprocess Fork Storms:**
  - *Symptom:* Idle laptop power consumption spikes from ~6W to 14–18W due to background monitoring loops.
  - *Mitigation:* Never invoke shell utilities (`pgrep`, `hyprctl`, `cat /sys/...`, `wpctl`) inside periodic timers. Use native D-Bus bindings, Hyprland event sockets, or `FileWatcher` sysfs monitors.
- **Intel CPU EPP Writes Refused (`EBUSY`):**
  - *Symptom:* Direct writes to `/sys/devices/system/cpu/cpu*/power/energy_perf_bias` fail silently or return `Device or resource busy`.
  - *Mitigation:* Always set the CPU scaling governor to `powersave` before writing EPP register values.
- **Inode Invalidation Breaking Inotify File Watchers:**
  - *Symptom:* Background watchers (`colors_wait.sh`, QuickShell `FileWatcher`) stop responding to file changes after an update script runs.
  - *Mitigation:* Updating files via `mv -f tmp target` creates a new inode, breaking existing inotify watches. Writes must update existing inodes directly (e.g., `cat tmp > target`) or trigger explicit IPC signals (`quickshell ipc call main reloadTheme`).