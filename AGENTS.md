# Antigravity Persistent Rules & System Memory

## 1. Automatic Post-Fix Documentation Requirement

After successfully resolving any issue, bug, or feature implementation:
- **Automatically update `~/nix/CHANGELOG.md`** under the current date section with a concise summary of changes.
- **Automatically update `~/nix/docs/decisions.md`** if an architectural or technical decision was made or superseded.
- **Automatically update `~/.gemini/config/skills/nixos-hyprland/SKILL.md`** if new systemic rules or workflow constraints were established.
- **Keep all documentation updates concise, practical, and bloat-free.**

---

## 2. Absolute Architectural & System Non-Negotiables

### A. Power & Performance Policy
- **Responsiveness is Non-Negotiable**: Never introduce artificial CPU/GPU frequency caps, delayed polling, or sluggish profile settings that make desktop interactions, browser/IDE tasks, or compositing laggy.
- **TLP Hardware Authority**: TLP 1.9.1 is the sole authority for hardware power profiles (`PLATFORM_PROFILE_ON_*`, EPP, ASPM). In `asusd.ron`, `change_platform_profile_on_battery/on_ac` must remain `false`. `asusd.service` is enabled strictly to enforce the 80% battery charge ceiling (`charge_control_end_threshold = 80`).
- **Balanced Profile Integrity**: The Balanced battery profile (`balance_performance`, Turbo `1`, Platform Profile `balanced`, ASPM `powersupersave`) is empirically validated and must remain untouched.

### B. QuickShell Architecture & Scaling Rules
- **Native Event-Driven Bindings Only**: Never launch periodic bash process loops (`workspaces.sh`, `power_state_watcher.sh`, `update_wait.sh`, `wpctl`) inside QML `Process` or `Timer`. Always use native C++ bindings:
  - `import Quickshell.Hyprland` (`focusedWorkspace`, `workspaces`, `rawEvent`) for 6ms workspace IPC.
  - `import Quickshell.Services.Pipewire` (`Pipewire.defaultAudioSink.audio`) for 8ms volume/mute D-Bus signals.
  - `Quickshell.Io.FileWatcher` for direct sysfs state changes.
- **Single-Pass Popup Scaler Bounds**: In popup QML components, `Scaler` must use `currentWidth: Screen.width` (single-pass reference). Never pass device-pixel bounds (`Config.masterWidth`) to popup `Scaler` instances, as it causes double-scaling multiplication (`1.33x x 1.33x = 1.77x`) that clips content off-screen.
- **Dynamic Workspace Tracking**: Workspace tracking in `TopBar.qml` must be dynamic (`Math.max(6, focusedId, maxOccupiedId)`) without arbitrary upper caps (no `<= 10` limits), preserving the 1–6 layout for standard workspaces.
- **Content-Minimum Music Geometry**: TopBar music widget column width (`mediaInfoColumn`) must be derived from non-negotiable content (`timeText.implicitWidth`). Short song titles (e.g. `命盤`) must **never** shrink the column or clip the timeline (`01:24 / 06:45`), and long titles must marquee scroll inside the title area.

### C. Media & Application Integrations
- **MPV MPRIS Integration**: `mpv` requires `(mpv.override { scripts = [ mpvScripts.mpris ]; })` in `modules/system/packages.nix` and `mpris.so` in `~/.config/mpv/scripts/` to broadcast D-Bus `org.mpris.MediaPlayer2` signals for local media tracking.
- **Native Wayland Environment**: Electron and Chromium apps must use native Wayland (`NIXOS_OZONE_WL = "1"`, `--ozone-platform-hint=wayland`) for native touchpad gestures.

---

## 3. Workflow & Verification Discipline

- **Read-Only First**: Always perform a read-only investigation and geometry/code trace before modifying files.
- **Pre-Deletion Audit**: Document what information an old script provided and its native replacement before retiring it.
- **Live Empirical Verification**: Editing a file does not equal completing a task. Always restart/rebuild and measure actual runtime behavior, latency, and power metrics.
