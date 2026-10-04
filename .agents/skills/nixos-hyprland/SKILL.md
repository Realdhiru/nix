---
name: NixOS / Hyprland Rice & Configuration
description: High-density operational reference for maintaining the user's NixOS desktop, Hyprland rice, and QuickShell widgets.
---

# NixOS / Hyprland Rice & Configuration

## 1. Operating Rules & Engineering Discipline

1. **Automatic Documentation Synchronization**:
   - Concise summary in `~/nix/CHANGELOG.md` under the current date.
   - Architectural/technical shifts in `~/nix/docs/decisions.md`.
   - Update `SKILL.md` / `AGENTS.md` only for systemic non-negotiables.
2. **Manual Git Authority**: Do **NOT** stage, commit, or push automatically. The user reviews, commits, and pushes all changes manually.
3. **High-Density / Signal-First Communication**:
   - Zero conversational filler, zero pleasantries, pure technical signal.
   - Exact clickable markdown links (`file:///...`), verified line ranges, and zero speculative hallucination.
   - Final turn summaries must be compact, structured bullet points designed for instant parsing.
4. **Verification Discipline & Anti-Patterns**:
   - **Screenshot Verification Ban (Token & Latency Discipline)**: Never capture screenshots (`grim`, image artifacts) to verify internal logic, widget toggles, or theme states. Capturing visual buffers consumes tens of thousands of tokens, induces multi-second latency, and provides zero semantic insight into internal state machines. Verify exclusively via deterministic log assertions (`console.log`), direct file inspection (`FileView`, `jq`), and native D-Bus/IPC queries. Screenshot captures are strictly reserved for explicit user-requested UI evaluations.
   - **Authoritative Process Recovery vs Stale Artifact Reverse-Engineering**: When QuickShell or helper daemons experience lifecycle shifts, dead PID files and abandoned IPC sockets (`/run/user/1000/quickshell/by-id/`) must not be polled or reverse-engineered. Always inspect the live daemon dynamically (`pgrep -fa quickshell`) or execute an authoritative clean reload via `reload.sh`.
   - **Measure the Mechanism Before Writing the Fix**: Capture actual runtime values, object identities, and event sources before editing code. Disprove or confirm theories with minimal probes rather than layering speculative fallbacks.
5. **Responsiveness is Non-Negotiable**:
   - Never throttle CPU frequency governors (`powersave` / EPP `power` / `quiet`) to artificially stretch battery life. Crushing CPU clocks cripples application startup (IDE, browser, compilers) and induces desktop compositing stutter.
   - Mobile power efficiency on modern silicon relies on rapid race-to-sleep (`balance_performance`, balanced platform profile, hardware ASPM `powersupersave`) paired with automated idle sleep (hypridle DPMS 120s, suspend 1800s).
6. **Global Consistency & Mandatory Confirmation Rule**:
   - **System-Wide Scope**: Applies to ANY visual/theme change across the entire desktop (QuickShell widgets, Fuzzel, hyprlock, topbar, window borders, `rules.lua`, etc.).
   - **Zero One-Off Overrides**: Every visual styling change (opacity, blur, color tokens, border, radius, spacing) must be applied across all matching components using shared tokens in a single pass.
   - **Mandatory Pre-Change Check-In**: Stop and ask the user for explicit confirmation before editing any UI/visual/theming files, detailing the exact proposed diffs, line numbers, and scope. Pure functional bug fixes with zero visual change are exempt.
7. **Ultra-Minimal Notification Format (Zero Sentences)**:
   - System notifications (`notify-send`) must NEVER include full sentences, paragraphs, or conversational explanations.
   - Notification content must remain strictly minimal: 1–3 words max (e.g. `"Coffee mode ON"`, `"Game Mode OFF"`, `"Hotspot ON"`), with NO secondary body text unless delivering strictly necessary dynamic data (such as SSID or IP). TopBar ticker (`NotifTicker.qml`) and desktop popups are designed for compact telemetry signals, not sentences.
8. **Zero Duplicate Process Policy for QuickShell**:
    - NEVER execute raw `quickshell -p ...` or `hyprctl eval "hl.exec_cmd('quickshell ...')"` when QuickShell is already running. Spawning duplicate `quickshell` processes creates overlapping topbars and layer-shell collisions.
    - ALWAYS perform clean reloads using `quickshell ipc -p ~/.config/hypr/scripts/quickshell/Shell.qml call main forceReload` or `~/nix/dotfiles/hypr/scripts/qs_manager.sh reload` (which issues `pkill -9 quickshell` before spawning a fresh instance).
9. **Cached-Widget Lifecycle, Clipboard, Tray & Battery Invariants**:
    - `Main.qml` sets cached `targetObj.visible = true` once and never resets it: `onVisibleChanged` fires exactly once per process. Per-open refresh/state-reset belongs in `showWidget()` (invoked on every open). `Shortcut{enabled: window.visible}` and `running: window.visible` animations otherwise stay armed forever.
    - Clipboard paste must declare MIME (`wl-copy --type image/png` / `--type text/plain;charset=utf-8`); bare `wl-copy` offers text only. Serialize copy→close (one `Process` + `onExited`), never racing `execDetached` pairs. `wl-paste --watch cliphist store` pairs live in supervised systemd user units (`Restart=always`), never unsupervised `exec_cmd` one-shots.
    - Battery runtime comes only from `Quickshell.Services.UPower` (`UPower.displayDevice`: `energy`, `energyCapacity`, `changeRate`, `timeToFull`). Never `FileView`/timer-poll sysfs (zero inotify). `isLaptopBattery` matches both `DisplayDevice` and `BAT0` — source from `displayDevice` directly.
    - SNI tray: clients register once at startup and never re-announce (a watcher restart empties the tray until clients restart). `kdeconnectd` exports no `StatusNotifierItem` — the icon requires `kdeconnect-indicator`. EasyEffects `--service-mode` and `blueman-applet` (GtkStatusIcon) cannot provide SNI icons. Never denylist `kdeconnect` while the indicator is autostarted.
    - Media telemetry lives only in root `MusicState.qml` (pragma Singleton); `TopBar.qml`/`SideBar.qml` alias it and must never own `playerctl --follow`, `music_info.sh`, json `FileView`, `cava`, or media timers. UI files are never merged for backend sharing.
    - Marker-file `FileView`s (`wallpaper_killed`, `gaming_mode`) require `onFileChanged: { reload(); updateSolidMode(); }` — directory-watch signals create/delete but the buffer stays stale otherwise. Never SIGHUP a terminal to reload config; `touch` the config files (wezterm hot-reloads on mtime).
    - Coffee state lives only in `SysData.coffeeActive` (+ `setCoffee()`); volume writes go only through `wpctl` (Pipewire is read-only for display). Every persistent QML `Process` stops itself in `Component.onDestruction` — engine reloads orphan children otherwise.
    - Battery direction comes only from `UPower.onBattery`, never `timeToFull` (0 when unestimable → discharge math while charging). Verify non-ASCII literals with `hexdump` after editing — they drop silently to `""`.
    - Mode indicators integrate into a host pill (coffee inside battery, on only while active) — never inside shared trays. Sidebar has no music UI (TopBar + MusicState own it). Visibility toggles require 3+ modifiers (plain binds can't require both Alts). Cold-start sync uses backend change signals, never deferred timers. Boot-critical `FileView`s use `blockLoading: true`.
    - Bar position switches sequence (incoming reserves first, outgoing releases after grace). Every runtime-flag `FileView` pairs `watchChanges` with `onFileChanged: reload()`. Substitute every template placeholder in every theme mode. Byte-patch non-ASCII glyphs + hexdump-verify.
    - Unconfirmed session locks quit loudly within 15s (never idle invisible). Lock spawn is single-flight; strays (alive + session unlocked + >45s) are reaped; lock-state matches binaries only, never cmdline mentions.
    - Never position layout against animating geometry (no anchor offsets bound to `childrenRect`/implicitHeight — fights tweens, causes jitter). `qs_manager.sh` brutal paths reap only PPID-1 follower strays (exact full-command patterns; never bare names, never clipboard owners).

## 2. Invariant Hardware & Architecture Policies

- **Power Authority**: TLP 1.9.1 is the sole hardware authority (`power.nix`). `asusd` only enforces the 80% charge ceiling (`charge_control_end_threshold = 80`). `asusd.ron` must keep `bat_profile = Balanced` and `change_platform_profile_on_battery = false` to prevent hardware throttling on battery.
- **Lid Policy**: `HandleLidSwitch = "ignore"`. Laptop lid closure never triggers unannounced suspend. Suspend is manual (`Shift + Esc`) or automated via 30-minute idle sleep.
- **Balanced Battery Profile**: `balance_performance`, Turbo `1`, Platform Profile `balanced`, ASPM `powersupersave` is empirically locked.
- **Coffee Mode & Persistent Idle Inhibition**:
  - `SUPER + CTRL + U` invokes `power.sh inhibit` to acquire `systemd-inhibit --what=idle:sleep --who=idle-inhibit-toggle --why="Coffee mode (idle inhibit)" --mode=block sleep infinity`.
  - State is canonically persisted in `~/.cache/quickshell/state.json` under `modes.coffee`.
  - `restore_state.sh` checks `modes.coffee` and automatically re-engages the systemd inhibitor on QuickShell reloads, Hyprland restarts, and cold boots until explicitly toggled off.
  - In `hypridle.conf`, idle timers enforce DPMS off at 120s, lock at 150s, and suspend at 1800s (30m) with `ignore_dbus_inhibit = false` and `ignore_systemd_inhibit = false`.
- **QuickShell IPC & Event-Driven Architecture**:
  - Native C++ event-driven bindings only (`Quickshell.Hyprland`, `Quickshell.Services.Pipewire`, `FileWatcher`, `FileView { watchChanges: true }`). Never fork bash polling loops or subprocess chains inside QML.
  - Sizing in popups must use `currentWidth: Screen.width` (single-pass reference). Never pass device-pixel bounds (`Config.masterWidth`) to popup `Scaler` instances to prevent double-scaling clipping.
  - **Scene-Visibility Gating for Positioning**: All `ListView.positionViewAtIndex()` and carousel settle passes must be strictly gated on `window.visible && view.width > 0`. Offscreen preloading (`visible: false`) creates unmapped scene graph nodes where coordinate math resolves to 0, causing negative clamp glitches on frame 0.
- **Out-of-Store Symlinks**: Home Manager `mkOutOfStoreSymlink` targets live `~/nix/dotfiles/` for instant zero-rebuild live updates.
- **Hardware Quirks**:
  - ASUS OLED brightness keys: rebound after hybrid-sleep in `hosts/nixos/hardware/asus.nix`.
  - Sonix Webcam: `v4l2loopback` `/dev/video10` pass-through via `hosts/nixos/hardware/sonix-webcam.nix`.
  - WirePlumber: `50-disable-libcamera.conf` disables libcamera to avoid UVC stream collision.

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
```
