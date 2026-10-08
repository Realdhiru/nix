# Antigravity Persistent Rules & System Memory

## 1. Automatic Post-Fix Documentation & Git Sync Requirement

After successfully resolving any issue, bug, or feature implementation:
- **Automatically update `~/nix/CHANGELOG.md`** under the current date section with a concise summary of changes.
- **Automatically update `~/nix/docs/decisions.md`** if an architectural or technical decision was made or superseded.
- **Automatically update `~/.gemini/config/skills/nixos-hyprland/SKILL.md`** if new systemic rules or workflow constraints were established.
- **Keep all documentation updates concise, practical, and bloat-free.**
- **Do NOT stage, commit, or push automatically.** The user will review, stage, commit, and push all changes themselves.

---

## 2. Absolute Architectural & System Non-Negotiables

### A. Power & Performance Policy
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
- **Lightweight Verification Only (No Wasteful Screenshot Loops)**: DO NOT run lengthy, compute-heavy test loops or repeatedly capture/scan screenshots using vision tools. Verify syntax and service states swiftly via minimal commands, then ask the user directly in output how the change looks and functions.

---

## 4. Token Efficiency & Communication Policy (High-Density / Caveman Mode)

- **Zero Conversational Filler**: No pleasantries, generic preambles, or conversational padding.
- **High Semantic Density**: Minimal tokens during reasoning and responses; pure technical signal.
- **Technical Rigor Preserved**: Code blocks, exact file paths, clickable markdown links, and diffs must remain 100% accurate.
- **Brief Final Summaries**: Final turn response must be ultra-compact bullet points designed for instant parsing.
