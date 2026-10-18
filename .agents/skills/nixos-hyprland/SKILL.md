---
name: NixOS / Hyprland Rice & Configuration
description: High-density operational reference for maintaining the user's NixOS desktop, Hyprland rice, and QuickShell widgets.
---

# NixOS / Hyprland Rice & Configuration

## 1. Operating Rules & Engineering Discipline

1. **Automated Multi-Doc Sync Invariant**:
   - Every code, script, keybind, driver, hardware quirk, or service modification strictly requires a synchronous multi-document audit before task completion:
     - `~/nix/README.md`: Feature matrices, architecture summaries, and keybindings.
     - `~/nix/CHANGELOG.md`: Granular changes under the current date.
     - `~/nix/docs/decisions.md`: Architectural decisions, technical invariants, and rationale.
     - `~/nix/docs/tacit_knowledge.md`: Hardware traps, udev quirks, and non-obvious fixes.
     - `SKILL.md` & `AGENTS.md`: Operational rice rules and non-negotiables.
   - Zero documentation drift allowed.
2. **Git Commit & Push Policy**: Only stage, commit, or push when the user explicitly instructs you to do so. NEVER stage, commit, or push automatically or autonomously without explicit user direction.
3. **High-Density / Signal-First Communication & Hardware Grounding**:
   - Zero conversational filler, zero pleasantries, pure technical signal.
   - Physical machine model authority: **ASUS Vivobook S 15 OLED (K5504VA / S5504VA)** (Intel Core i5-13500H, 2.8K 120Hz OLED). Never misidentify as Zenbook or any other lineup.
   - Exact clickable markdown links (`file:///...`), verified line ranges, and zero speculative hallucination.
   - Final turn summaries must be compact, structured bullet points designed for instant parsing.
4. **Three Core Architecture Invariants (Mandatory on All Refactors & Implementations)**:
   - **Pillar 1: Maximum Performance (Zero Lag, Race-to-Sleep)**: Interactive hot paths must run in sub-millisecond to sub-5ms times. No slow runtime-interpreted Python/Node scripts in hot paths (native C/Rust, Qt/QML, POSIX `jq`/`awk` only). Zero-copy pipelines (`--enable-zero-copy`) and direct Wayland/Ozone protocols everywhere.
   - **Pillar 2: Maximum Battery Life (Deep C-States, Fixed-Function Hardware Offload)**: Maximize package $C8/C10$ sleep states by eliminating periodic polling loops (`Timer`, shell loops) in favor of event-driven D-Bus/IPC/inotify. Offload video/audio compute to hardware ASICs (Intel QuickSync VA-API). Inhibit glass blur/shaders behind 60/120fps video and on battery.
   - **Pillar 3: Maximum Cross-Hardware Reproducibility**: Pure declarative Nix derivations and Home Manager `home.file` definitions over manual imperative file mutations. Dynamic token/scaler resolution (`Theme.colors.*`, screen scale) instead of hardcoded hex or pixel values. Zero machine-specific hardcoded paths outside `hosts/` and `user.nix`.
5. **Verification Discipline & Anti-Patterns**:
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
  - WirePlumber: `50-disable-libcamera.conf` disables libcamera to avoid UVC stream collision.
  - Native PipeWire Equalizer: System audio uses `libpipewire-module-filter-chain` (10-band biquad peaking filters with $Q = 1.414$, virtual sink priority 2100) and native `pw-cli` gain control instead of external daemon apps.
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

## 4. Second-Brain & Obsidian Vault Architecture Standards

- **Single Vault Root**: All vaults live strictly under `~/Projects/Vault/<subject>-brain/` (e.g. `~/Projects/Vault/nix-brain`).
- **Zero Meta-Bloat**: No "hub" folders, templates directories, or helper scripts. Only actual domain documentation.
- **Zero Emojis**: No decorative emojis in file names, headers, or bullet points.
- **3-Tier Architecture**: Layer 3 (`00 - Maps of Content`), Layer 2 (`Concepts & Synthesis Notes`), Layer 1 (`Specifications & Runbooks`).
- **Contextual Trade-Offs**: Every architectural choice must answer *"Why this and not X?"* with a concrete table.
- **Battle-Tested Traps**: Non-obvious failure modes, race conditions, and bug post-mortems must be preserved as first-class notes.


## Wine/Proton storage janitor (gameclean)
gameclean — packaged in pkgs/gameclean.nix (docs/gameclean.md). Wine games scatter files across 5 locations (game dir, Wine prefixes, umu prefix caches, ~/.cache, Lutris ymls); run `gameclean` (preview) after any game uninstall or failed install, `gameclean -y` only after reading the preview. Working Lutris-referenced titles are never flagged.
