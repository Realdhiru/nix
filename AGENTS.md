# Antigravity Persistent Rules & System Memory

## 1. Automated Post-Fix Documentation Invariant & Git Requirement

Whenever an agent touches or modifies any feature, script, keybind, hardware quirk, driver, service, or configuration:
- **Mandatory Multi-Doc Audit & Synchronous Update**: The agent MUST review and immediately update all affected documentation before declaring the task complete:
  - **`~/nix/README.md`**: Update feature matrices, architecture summaries, and keybindings tables whenever user-facing capabilities or keybinds change.
  - **`~/nix/CHANGELOG.md`**: Record every bugfix, feature, or optimization under the current date with concise technical bullets.
  - **`~/nix/docs/decisions.md`**: Document every architectural or technical decision made, superseded, or stabilized.
  - **`~/nix/docs/tacit_knowledge.md`**: Document non-obvious traps, hardware quirks, udev rules, or subsystem workarounds discovered.
  - **`~/.gemini/config/skills/nixos-hyprland/SKILL.md` & `~/nix/.agents/skills/nixos-hyprland/SKILL.md`**: Keep rice, widget, and NixOS operational guidelines synchronized.
- **Zero Documentation Drift**: Code changes and documentation updates must happen in the exact same turn.
- **Keep all documentation updates concise, practical, and bloat-free.**
- **Git Commit & Push Policy**: Only stage, commit, or push when the user explicitly instructs you to do so. NEVER stage, commit, or push automatically or autonomously without explicit user direction.

---

## 2. Absolute Architectural & System Non-Negotiables

### A. Three Core Architecture Invariants (Mandatory on All Refactors & Implementations)
Every new feature, refactor, script, service, or configuration must adhere to these three pillars:
1. **Pillar 1: Maximum Performance (Zero Lag, Race-to-Sleep)**
   - Desktop and interactive hot paths must execute in sub-millisecond to sub-5ms times.
   - Python, Node, Ruby, and slow runtime-interpreted scripts are strictly forbidden in hot paths (keybinds, polling, event watchers, IPC handlers, theme generation, popups). Use compiled native C/Rust binaries, native C++ Qt/QML bindings, or instant POSIX C utilities (`jq`, `awk`, coreutils).
   - Zero-copy pipelines (`--enable-zero-copy`, VA-API GL direct surface sharing) and native Wayland/Ozone protocols everywhere. Never introduce artificial CPU/GPU frequency caps or sluggish polling loops.
2. **Pillar 2: Maximum Battery Life (Deep C-States, Fixed-Function Hardware Offload)**
   - Maximize hardware sleep states ($C8/C10$ package sleep) by eliminating periodic polling loops (`Timer`, shell loops). All desktop daemons must be event-driven (D-Bus, udev, inotify, socket IPC).
   - Offload compute-heavy media workloads to fixed-function hardware ASICs (Intel QuickSync VA-API) instead of CPU software decoding.
   - Solid fallback (`SOLID_BG`) and shader-inhibition on power-sensitive apps/modes (disable compositor glass blur behind running 60/120fps video).
   - Respect TLP 1.9.1 hardware authority and the empirically locked Balanced profile (`balance_performance`, balanced platform profile, ASPM `powersupersave`).
3. **Pillar 3: Maximum Cross-Hardware Reproducibility**
   - Pure declarative Nix derivations and Home Manager `home.file` definitions over ad-hoc imperative scripts in `~/.local/bin/` or manual configs.
   - Portable dynamic theme and token resolution (dynamic `Theme.colors.*` over hardcoded hex, dynamic font discovery, relative geometry scaler calculations).
   - Standardized Wayland protocols (XDG desktop portal, Ozone Wayland hint, pipewire-pulse) that work deterministically across Intel, AMD, and Nvidia platforms without proprietary lock-ins or hardcoded machine paths outside `hosts/` and `user.nix`.

### B. Power & Performance Policy
- **Hardware Model Authority**: The physical machine is an **ASUS Vivobook S 15 OLED (K5504VA / S5504VA)** (Intel Core i5-13500H, 2.8K 120Hz OLED). Never misidentify this system as Zenbook, ROG, or Zephyrus.
- **Responsiveness is Non-Negotiable**: Never introduce artificial CPU/GPU frequency caps, delayed polling, or sluggish profile settings that make desktop interactions, browser/IDE tasks, or compositing laggy.
- **TLP Hardware Authority**: TLP 1.9.1 is the sole authority for hardware power profiles (`PLATFORM_PROFILE_ON_*`, EPP, ASPM). In `asusd.ron`, `change_platform_profile_on_battery/on_ac` must remain `false`. `asusd.service` is enabled strictly to enforce the 80% battery charge ceiling (`charge_control_end_threshold = 80`). `asusd.ron` must keep `bat_profile = Balanced` to prevent hardware firmware throttling on battery.
- **Balanced Profile Integrity**: The Balanced battery profile (`balance_performance`, Turbo `1`, Platform Profile `balanced`, ASPM `powersupersave`) is empirically validated and must remain untouched.
- **Fast Compiled Execution & Python Ban in Hot Paths**: Never introduce slow runtime-interpreted scripts (Python, node, ruby) or heavy subprocess pipelines in desktop hot paths (keybind cycling, status polling, IPC handlers, popup data loaders, theme generation). Always use compiled native C/Rust binaries, native C++ Qt/QML bindings, or instant POSIX C utilities (`jq`, `awk`, coreutils). Python is strictly prohibited on hot paths.


### B. QuickShell Architecture & Scaling Rules
- **Native Event-Driven Bindings Only**: Never launch periodic bash process loops (`workspaces.sh`, `power_state_watcher.sh`, `update_wait.sh`, `wpctl`) inside QML `Process` or `Timer`. Always use native C++ bindings:
  - `import Quickshell.Hyprland` (`focusedWorkspace`, `workspaces`, `rawEvent`) for 6ms workspace IPC.
  - `import Quickshell.Services.Pipewire` (`Pipewire.defaultAudioSink.audio`) for 8ms volume/mute D-Bus signals.
  - `Quickshell.Io.FileWatcher` for direct sysfs state changes.
- **Scene-Visibility Gating for Positioning**: All `ListView.positionViewAtIndex()` and carousel centering passes must be strictly gated on `window.visible && view.width > 0`. Offscreen preloading (`visible: false`) creates objects outside the active visual scene graph where coordinate math and view width are unmapped, causing bad clamps on frame 0.
- **Global Consistency & Mandatory Confirmation Rule**:
  - **System-Wide Scope**: Applies to ANY visual/theme change across the entire system — QuickShell widgets, Fuzzel, hyprlock, waybar/topbar, window borders, `rules.lua` opacity/blur rules, or any other app/window whose appearance is part of this desktop system (not just QuickShell).
  - **Zero One-Off Overrides**: NEVER make a change scoped to a single widget/app's look in isolation. Any visual change (opacity, blur, color token, border, radius, spacing) must be applied consistently across every widget/app that shares that visual category in the same pass, using shared Theme/Config tokens.
  - **Mandatory Check-In Before UI Changes**: Before applying ANY UI/visual/theme change — whether explicitly requested or proposed as a side effect of a fix — you MUST stop and ask the user for guidance first. Present the exact proposed changes, file paths, line numbers, and whether changes are scoped or system-wide. Do NOT proceed until the user explicitly confirms. (Exception: pure functional bug fixes with zero visual/behavioral changes do not require pre-confirmation).
- **Single-Pass Popup Scaler Bounds**: In popup QML components, `Scaler` must use `currentWidth: Screen.width` (single-pass reference). Never pass device-pixel bounds (`Config.masterWidth`) to popup `Scaler` instances, as it causes double-scaling multiplication (`1.33x x 1.33x = 1.77x`) that clips content off-screen.
- **Dynamic Workspace Tracking**: Workspace tracking in `TopBar.qml` must be dynamic (`Math.max(6, focusedId, maxOccupiedId)`) without arbitrary upper caps (no `<= 10` limits), preserving the 1–6 layout for standard workspaces.
- **Content-Minimum Music Geometry**: TopBar music widget column width (`mediaInfoColumn`) must be derived from non-negotiable content (`timeText.implicitWidth`). Short song titles (e.g. `命盤`) must **never** shrink the column or clip the timeline (`01:24 / 06:45`), and long titles must marquee scroll inside the title area.

### C. Media & Application Integrations
- **MPV MPRIS Integration**: `mpv` requires `(mpv.override { scripts = [ mpvScripts.mpris ]; })` in `modules/system/packages.nix` and `mpris.so` in `~/.config/mpv/scripts/` to broadcast D-Bus `org.mpris.MediaPlayer2` signals for local media tracking.
- **Native Wayland Environment**: Electron and Chromium apps must use native Wayland (`NIXOS_OZONE_WL = "1"`, `--ozone-platform-hint=wayland`) for native touchpad gestures.
- **Web Apps Hardware Video Acceleration Authority**: All Brave web apps and browser windows must receive native VA-API zero-copy hardware acceleration via `~/.local/bin/brave` (`--use-gl=angle --use-angle=gl --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations --enable-zero-copy`). High-framerate video applications (YouTube) must remain 100% solid opacity (`1.0`) with `idle_inhibit = "focus"`. WhatsApp must never have translucent glass opacity.

### D. Notification Length & Formatting Policy
- **Minimum Length Only (Zero Sentences)**: System notifications (`notify-send`) must NEVER emit conversational sentences, explanatory bodies, or descriptive prose. Notification text must be ultra-minimal: 1–3 words max (e.g., `"Coffee mode ON"`, `"Game Mode OFF"`, `"Hotspot ON"`), with NO secondary body text unless delivering strictly essential dynamic telemetry (e.g. connection SSID or IP). TopBar ticker (`NotifTicker.qml`) and minimal notification cards are constrained visual elements designed for concise state signals only.

---

## 3. Workflow & Verification Discipline

- **Read-Only First**: Always perform a read-only investigation and geometry/code trace before modifying files.
- **Pre-Deletion Audit**: Document what information an old script provided and its native replacement before retiring it.
- **Never Delete From ~/Projects**: Never delete files or directories inside `~/Projects/` or its subfolders, as they may contain critical user backups, reference repositories, or independent projects.
- **Never Test Lockscreen**: Never test or execute the lockscreen (`Lock.qml`) directly/autonomously, as it breaks the PAM session and session lock state upon logging back in.
- **Live Empirical Verification**: Editing a file does not equal completing a task. Always restart/rebuild and measure actual runtime behavior, latency, and power metrics.
- **QuickShell Visual & Cold-Start Protocol**: Before declaring any QuickShell widget done:
  - Verify layout proportions and check for leftover/dead space or mismatched button grids.
  - Verify anti-bleed layering so high-contrast wallpaper sketches/lines do not show through translucent glass panels.
  - Empirically test the **FIRST open** immediately after a fresh cold `forceReload` to ensure no shape snap, shrink, or uninitialized geometry glitch occurs.
- **Zero Duplicate Process Policy**: NEVER execute raw `quickshell -p ...` or `hyprctl eval "hl.exec_cmd('quickshell ...')"` when QuickShell is running. ALWAYS reload via `quickshell ipc -p ~/.config/hypr/scripts/quickshell/Shell.qml call main forceReload` or `~/nix/dotfiles/hypr/scripts/qs_manager.sh reload`.
- **Zero Rapid Texture/Buffer Thrashing**: NEVER execute rapid back-to-back visual transitions (wallpaper kill/restore toggles, shader compile loops, multiple reload bursts) within milliseconds. The Intel integrated GPU ring buffer (`rcs0`) hangs under tight allocation bursts, causing an unrecoverable Aquamarine DRM page-flip crash (`CHyprOpenGLImpl::begin` assertion failure $\rightarrow$ `SIGABRT` $\rightarrow$ Safe Mode). All visual mode tests must settle with minimum 1.5s separation.
- **Lightweight Verification Only (No Wasteful Screenshot Loops)**: DO NOT run lengthy, compute-heavy test loops or repeatedly capture/scan screenshots using vision tools. Verify syntax and service states swiftly via minimal commands, then ask the user directly in output how the change looks and functions.

---

## 4. Token Efficiency & Communication Policy (High-Density / Caveman Mode)

- **Zero Conversational Filler**: No pleasantries, generic preambles, or conversational padding.
- **High Semantic Density**: Minimal tokens during reasoning and responses; pure technical signal.
- **Technical Rigor Preserved**: Code blocks, exact file paths, clickable markdown links, and diffs must remain 100% accurate.
- **Brief Final Summaries**: Final turn response must be ultra-compact bullet points designed for instant parsing.

---

## 5. Second-Brain & Obsidian Vault Architecture Standards

Whenever an agent is instructed to create, expand, or document knowledge in Obsidian vaults:
- **Location Invariant**: All second-brain vaults MUST live directly under `~/Projects/Vault/<subject>-brain/` (e.g. `~/Projects/Vault/nix-brain`). Never scatter vault folders across `~` or `~/Projects/`.
- **Zero Meta-Bloat Invariant**: NEVER create "hub" meta-directories, template folders, "how to use" manuals, or standalone helper scripts inside vaults. Jump straight into authoritative domain documentation.
- **Strict Aesthetic Standard (Zero Emojis)**: NEVER use cosmetic/decorative emojis in file names, note headers, or bullet points. All notes must look like human-crafted, professional systems engineering whitepapers.
- **The 3-Tier Layered Architecture**:
  - `00 - Maps of Content (MOC)`: 1–3 top-level router notes that cluster the graph view cleanly around core hubs.
  - `Concepts & Synthesis Notes`: In-depth trade-off analyses answering *"Why this and not the alternative?"* with side-by-side comparison tables.
  - `Specifications & Runbooks`: Concrete primitives, kernel/hardware registers, CLI commands, and post-mortems for non-obvious traps and bugs.
- **Mandatory Depth**: Notes must never be shallow 3-bullet summaries. Every note must document:
  1. Context and failure modes of naive approaches.
  2. Concrete implementation code and exact parameters.
  3. Structured Trade-Off Matrix.
  4. Non-obvious edge cases, race conditions, and traps discovered in production.
  5. Bidirectional wikilinks (`[[...]]`) connecting up to its parent MOC and related sibling concepts.

