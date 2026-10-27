# System Architecture & Technical Specifications

Generic technical facts, architecture invariants, and subsystem designs. Machine-specific facts live in `hosts/<host>/PERSONAL.md`. Behavior rules live in `AGENTS.md`.

## 1. Core Architecture Pillars
- **Declarative Nix Flakes**: System configuration managed via `flake.nix` and `flake.lock`. Pure Nix derivations over ad-hoc imperative scripts.
- **Out-of-Store Symlinks**: Home Manager `mkOutOfStoreSymlink` targets live `~/nix/dotfiles/` for instant live updates (`SUPER + R`) without requiring full rebuilds.
- **Event-Driven IPC (Zero Polling)**: Desktop daemons and UI widgets bind directly to kernel/daemon event signals (Hyprland socket2 in ~6ms, PipeWire in ~8ms, UPower D-Bus, `FileWatcher` for sysfs state). Periodic bash polling loops, timers, and subshell loops are strictly forbidden.
- **Fast Compiled Execution**: Native compiled binaries (Rust, C/C++), Qt/QML bindings, or instant POSIX C utilities (`jq`, `awk`, coreutils) in interactive paths. No Python or Node in hot paths.
- **Dynamic Theming (SSOT)**: Semantic color tokens dynamically extracted from wallpaper via Wallust (Rust, K-Means in Lch colorspace). Hardcoded hex color literals in widgets are forbidden.

## 2. QuickShell Architecture & Widget Invariants
- **Native Event-Driven Bindings**: Use `Quickshell.Hyprland` (`focusedWorkspace`, `workspaces`, `rawEvent`), `Quickshell.Services.Pipewire` (`defaultAudioSink.audio`), `Quickshell.Io.FileWatcher`, and `FileView { watchChanges: true }`. Never fork bash process loops inside QML `Process` or `Timer`.
- **Scene-Visibility Gating**: All `ListView.positionViewAtIndex()`, carousel centering, and layout settle passes must be strictly gated on `window.visible && view.width > 0`. Offscreen preloading (`visible: false`) creates unmapped scene graph nodes where coordinate math resolves to 0, causing negative clamp glitches on frame 0.
- **Single-Pass Popup Scaler Bounds**: In popup components, `Scaler` must use `currentWidth: Screen.width` (single-pass reference). Never pass device-pixel master width bounds to avoid double-scaling clipping (`1.33x * 1.33x = 1.77x`).
- **Cached-Widget Lifecycle Contract**: `Main.qml` sets cached `targetObj.visible = true` once and never resets it (`onVisibleChanged` fires once per process). Per-open refresh or state-reset belongs in `showWidget()` (invoked on every open). `Shortcut { enabled: window.visible }` and `running: window.visible` animations stay armed otherwise.
- **Dynamic Workspaces**: Workspace tracking in bar modules is dynamic (`Math.max(6, focusedId, maxOccupiedId)`) without arbitrary caps, preserving standard 1–6 layouts. IPC bursts are coalesced through a 16ms single-flight debounce timer (`wsDebounceTimer`).
- **Layout Anchoring vs Animations**: Never bind layout container offsets (`y`, `anchors`) to tweening dimensions (`implicitHeight`, `childrenRect`) during delegate mount/unmount animations to prevent coordinate fighting and indicator jitter.
- **Battery Telemetry SSOT**: Battery runtime sourced exclusively from `Quickshell.Services.UPower` (`UPower.displayDevice`: `energy`, `energyCapacity`, `changeRate`, `timeToFull`). Battery direction comes only from `UPower.onBattery`, never `timeToFull`.
- **System Tray (SNI)**: Clients register once at startup and do not re-announce. `kdeconnectd` requires `kdeconnect-indicator` for SNI.
- **Media Telemetry SSOT**: Media state lives strictly in root singleton `MusicState.qml`. Bar widgets alias it and never own separate playerctl processes, cava, or timers.
- **Styling & Tokens**: Visual properties (colors, borders, radius, fonts, motion) must derive strictly from shared tokens (`Theme.colors.*`, `Motion.qml`). Text contrast floor >= 4.5:1 (WCAG AA). Anti-bleed foundation fill (`crust` at 0.16–0.18) layered behind frosted glass cards.
- **Notifications**: Ultra-minimal format (1–3 words max, zero sentences, no secondary body unless critical dynamic telemetry). Explicit sender app name required (`notify-send -a "<App>"`).
- **Reload Authority**: QuickShell reloaded only via IPC (`quickshell ipc -p ~/.config/hypr/scripts/quickshell/Shell.qml call main forceReload`) or `qs_manager.sh reload`.

## 3. Wallpaper Subsystem Pipeline
- **Pipeline Routing**:
  - Animated GIFs and video files (`mp4`, `mkv`, `mov`, `webm`, `gif`) route to `mpvpaper` with auto-pause (`-p`), hardware VA-API video decode (`--hwdec=auto-safe`), and background `.mp4` caching in `~/.cache/converted_gifs/` (starts in <0.15s).
  - Static images (`png`, `jpg`, `jpeg`, `webp`) route to `awww img` with `--filter Bilinear`, `--outputs "$OUT_JOINED"`, and `--transition-type none` (<0.1s apply).
- **Systemd Service Architecture**:
  - `awww-daemon.service`: Launched with `--no-cache --format argb` to prevent unbounded raw frame disk cache accumulation.
  - `mpvpaper@<out>.service`: Per-output templated unit consuming `%h/.local/state/mpvpaper/%i.env` with `%i` (verbatim output name, preserving dashes).
- **Wallpaper Kill & Unkill**:
  - Kill mode enforces solid black background, turns off window blur and shadows, and enforces solid window opacities (`1.0 override`).
  - Unkill restores transparent window glass, re-enables blur, and restores the previous wallpaper without full compositor reload (`hyprctl reload` no longer used).

## 4. Audio & Media Pipeline
- **Native PipeWire 10-Band Equalizer**: Filter chain (`libpipewire-module-filter-chain`) biquad equalizer sink (`effect_input.eq10`, Q = 1.414, virtual sink priority 2200). All audio applications stream through the EQ sink.
- **Automatic Handover**: EQ sink passively forwards audio to the highest-priority physical endpoint automatically (external devices priority 2150; internal speakers priority 1000).
- **Bluetooth AAC stereo**: WirePlumber rule `bluetooth.autoswitch-to-headset-profile = false` prevents AVDTP codec renegotiation crashes, locking high-quality A2DP stereo.
- **WebRTC Microphone Denoising**: `libpipewire-module-echo-cancel` with `monitor.mode = true` binds to the microphone array, cancels speaker playback acoustic bleed from `effect_input.eq10:monitor`, and publishes `echo_cancel_source` at priority 2100 with zero daemon overhead.
- **Multi-Output Audio Broadcast**: `Super + Ctrl + V` (`toggle_multi_sink.sh` / `pw-broadcast`) dynamically broadcasts equalizer output across all connected external endpoints simultaneously via sub-2ms `pw-link` graph connections, auto-compensating Bluetooth buffer latency (340ms) on wired channels.
- **MPV MPRIS Integration**: `mpv` overridden with `mpvScripts.mpris` symlinked to `~/.config/mpv/scripts/mpris.so` to broadcast D-Bus `org.mpris.MediaPlayer2` signals.

## 5. Power & State Management Design
- **State Directory Invariant**:
  - Persistent desktop state lives strictly in `${XDG_STATE_HOME:-$HOME/.local/state}/desktop/` (subdivided by area: `wallpaper/`, `power/`, `audio/`). State writes must be atomic (`tmp` file + `mv -f` in the same directory).
  - Regenerable cache files belong in `~/.cache`.
  - *Known Legacy Violations (scheduled for migration)*: `coffee state.json` (`~/.cache/quickshell/state.json`), `wallpaper_killed` (`~/.cache/wallpaper_killed`), `gaming_mode` (`~/.cache/gaming_mode`), `rec_pid` (`~/.cache/rec_pid`), `qs_power_profile` (`~/.cache/qs_power_profile`).
- **Race-to-Sleep Strategy**: Maximize package C-state sleep ($C8/C10$) by bursting tasks at full frequency and sleeping immediately. Periodic polling loops are banned.
- **Coffee Mode & Persistent Idle Inhibition**:
  - `SUPER + CTRL + U` invokes `power.sh inhibit` to acquire `systemd-inhibit --what=idle:sleep --who=idle-inhibit-toggle --why="Coffee mode (idle inhibit)" --mode=block sleep infinity`.
  - `restore_state.sh` checks state and automatically re-engages the inhibitor across QuickShell reloads, Hyprland restarts, and cold boots until explicitly toggled off.
  - In `hypridle.conf`, idle timers enforce DPMS off at 120s, lock at 150s, and suspend at 1800s (30m) with `ignore_dbus_inhibit = false` and `ignore_systemd_inhibit = false`.
- **Power Button Screen Toggle**: Physical power button (`XF86PowerOff`) bound to `power.sh display toggle` with locked Hyprland dispatcher. `key_press_enables_dpms = true` and `mouse_move_enables_dpms = true` restore display instantly on input.

## 6. Wayland, Compositor & Application Integration
- **Native Wayland Environment**: `NIXOS_OZONE_WL = "1"` and `--ozone-platform-hint=wayland` exported globally for Chromium and Electron apps.
- **Hardware Video Acceleration**: Native VA-API zero-copy flags enabled (`--use-gl=angle --use-angle=gl --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations --enable-zero-copy`). Video apps remain 100% solid opacity (`1.0`) with `idle_inhibit = "focus"`.
- **Glassmorphism Opacity Hierarchy (`rules.lua`)**:
  - `0.47`: Ambient AI assistants (ChatGPT)
  - `0.60`: File management, web apps
  - `0.65`: Knowledge base (Obsidian)
  - `0.70`: Terminal (Alacritty)
  - `1.00`: Solid mode override (gaming mode, wallpaper killed, power-saver, video playback)
- **Compositor Layer Blur**: Narrowed strictly to namespaces `^(quickshell|qs-master|qs-notif-toast)$` with `ignore_alpha = 0.05`. Full-screen transparent overlay surfaces (`qs-floating-overlay`) are excluded from blur passes.
- **HiDPI Toolkit Scaling**: `GDK_SCALE = "2"`, `QT_AUTO_SCREEN_SCALE_FACTOR = "1"`, `QT_ENABLE_HIGHDPI_SCALING = "1"` in `env.lua`. Chromium download bubbles disabled in favor of in-window progress to avoid detached subsurface coordinate misplacement.

## 7. Operational Discipline & Safety Rules
- **Intel GPU Ring Protection**: Minimum 1.5s separation between manual visual mode test steps to prevent integrated GPU `rcs0` execution ring saturation and Aquamarine DRM page-flip crashes (`CHyprOpenGLImpl::begin` assertion failure -> `SIGABRT` -> Safe Mode). Product code drops overlapping requests while a transition is in flight.
- **Lockscreen Ban**: Never execute or test `Lock.qml` directly or autonomously (desynchronizes PAM session state and locks the user out).
- **Workspace Protection**: Never delete files or directories inside `~/Projects/` or its subfolders.
- **Safe Rebuild Pipeline**: Never invoke bare `nixos-rebuild`. Always execute the `rebuild "<commit message>"` shell function, which formats code, dry-builds, switches, and runs post-switch health checks with automatic rollback.
