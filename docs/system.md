# System Architecture & Technical Specifications

Generic technical facts, architecture invariants, and subsystem designs. Machine-specific facts live in `hosts/<host>/PERSONAL.md`. Behavior rules live in `AGENTS.md`.

## 1. Core Architecture Pillars
- **Simplified Configuration Structure**: Shared implementation lives in `modules/` and `dotfiles/`; hardware detection lives in `hosts/<host>/hardware-configuration.nix` and `system.nix`; personal identity, home path, and defaults live in `user.nix`. `home.nix` imports the Home Manager desktop module; feature owners are `modules/home/{audio,desktop-state,monitors,quickshell,shell,theme,wallpaper}.nix`, with application setup composed in `modules/home/desktop.nix`. TLP hardware policy stays in `modules/system/power.nix`.
- **Declarative Nix Flakes**: System configuration managed via `flake.nix` and `flake.lock`. Pure Nix derivations over ad-hoc imperative scripts.
- **Out-of-Store Symlinks**: Home Manager `mkOutOfStoreSymlink` targets live `~/nix/dotfiles/` for instant live updates (`SUPER + R`) without requiring full rebuilds.
- **Event-Driven IPC with Bounded Sampling**: Desktop daemons and UI widgets prefer kernel/daemon signals (Hyprland socket2, PipeWire, UPower D-Bus, and `FileWatcher`). FocusTime keeps one-second accounting ticks but publishes live JSON on app changes or every 15 seconds; battery audit samples every 60 seconds on battery. Unbounded polling loops in interactive QML remain forbidden.
- **Bounded Command Resolution**: Bash wrappers apply `timeout` to the external `hyprctl` executable through `env`; `timeout` cannot invoke shell builtins such as `command` itself.
- **Cleanup Safety**: `gameclean -y` refuses when unreferenced or stray Wine prefixes are present unless `--include-unmanaged-prefixes` is explicitly supplied; preview mode remains the default.
- **Fast Compiled Execution**: Native compiled binaries (Rust, C/C++), Qt/QML bindings, or instant POSIX C utilities (`jq`, `awk`, coreutils) in interactive paths. No Python or Node in hot paths.
- **Dynamic Theming (SSOT)**: Semantic color tokens dynamically extracted from wallpaper via Wallust (Rust, K-Means in Lch colorspace). Hardcoded hex color literals in widgets are forbidden.

## 2. QuickShell Architecture & Widget Invariants
- **Native Event-Driven Bindings**: Use `Quickshell.Hyprland` (`focusedWorkspace`, `workspaces`, `rawEvent`), `Quickshell.Services.Pipewire` (`defaultAudioSink.audio`), `Quickshell.Io.FileWatcher`, and `FileView { watchChanges: true }`. Never fork bash process loops inside QML `Process` or `Timer`.
- **Scene-Visibility Gating**: All `ListView.positionViewAtIndex()`, carousel centering, and layout settle passes must be strictly gated on `window.visible && view.width > 0`. Widgets are created on first open and cached afterward; hidden widgets are not eagerly instantiated at startup, so their background processes and timers remain dormant until needed.
- **Power-Saver Animation Gating**: Decorative infinite QML animations and title marquees bind to `Config.animationsEnabled`, which is false when the observed profile is `power-saver`; visibility gating remains in place. Recording and action-status indicators remain available. This pauses decorative loops without adding profile polling or widget processes.
- **Bounded Interactive Helpers**: Audio recovery and sink discovery put deadlines around PipeWire, WirePlumber, ALSA, and systemd calls. Sink cycling is serialized; FocusTime seeks use a locked, atomic latest-request file and a single worker rather than a stale marker or debounce sleep.
- **Fuzzel Theme Ownership**: Wallust only writes generated theme data under `~/.cache/theme/`. `fuzzel_menu.sh` reads the palette and passes runtime colors to Fuzzel; it does not rewrite the tracked or linked `fuzzel.ini`.
- **Atomic Video Loop Output**: `scripts/make-loop.sh` encodes to a temporary file in the destination directory and renames it only after success. Batch errors are counted while remaining inputs continue.
- **Single-Pass Popup Scaler Bounds**: In popup components, `Scaler` must use `currentWidth: Screen.width` (single-pass reference). Never pass device-pixel master width bounds to avoid double-scaling clipping (`1.33x * 1.33x = 1.77x`).
- **Cached-Widget Lifecycle Contract**: `Main.qml` sets cached `targetObj.visible = true` once and never resets it (`onVisibleChanged` fires once per process). Per-open refresh or state-reset belongs in `showWidget()` (invoked on every open). `Shortcut { enabled: window.visible }` and `running: window.visible` animations stay armed otherwise.
- **Dynamic Workspaces**: Workspace tracking in bar modules is dynamic (`Math.max(6, focusedId, maxOccupiedId)`) without arbitrary caps, preserving standard 1–6 layouts. IPC bursts are coalesced through a 16ms single-flight debounce timer (`wsDebounceTimer`).
- **Layout Anchoring vs Animations**: Never bind layout container offsets (`y`, `anchors`) to tweening dimensions (`implicitHeight`, `childrenRect`) during delegate mount/unmount animations to prevent coordinate fighting and indicator jitter.
- **Battery Telemetry SSOT**: Battery runtime sourced exclusively from `Quickshell.Services.UPower` (`UPower.displayDevice`: `energy`, `energyCapacity`, `changeRate`, `timeToFull`). Battery direction comes only from `UPower.onBattery`, never `timeToFull`.
- **FocusTime Persistence**: The Rust daemon keeps its one-second tick buffer until all grouped SQLite writes and the transaction commit succeed. A database error is logged and the same records remain available for retry rather than being silently dropped.
- **System Tray (SNI)**: Clients register once at startup and do not re-announce. `kdeconnectd` requires `kdeconnect-indicator` for SNI.
- **Media Telemetry SSOT**: Media state lives strictly in root singleton `MusicState.qml`. Bar widgets alias it and never own separate playerctl processes, cava, or timers.
- **Visualizer Lifecycle**: CAVA runs only while media is playing, a title is visible, and the TopBar visualizer is shown; it stops when the bar or visualizer is hidden.
- **Styling & Tokens**: Visual properties (colors, borders, radius, fonts, motion) must derive strictly from shared tokens (`Theme.colors.*`, `Motion.qml`). Text contrast floor >= 4.5:1 (WCAG AA). Anti-bleed foundation fill (`crust` at 0.16–0.18) layered behind frosted glass cards.
- **Unified Glass Notification Styling (SSOT)**: Notification pills in both TopBar center and Sidebar overlay (`NotifToast.qml`) bind directly to `Config.effectivePopupOpacity`. Isolated or dark opacity floors are banned. When the user tweaks appearance opacities, all bars, cards, popups, and toast notifications morph simultaneously.
- **Notifications**: Ultra-minimal format (1–3 words max, zero sentences, no secondary body unless critical dynamic telemetry). Explicit sender app name required (`notify-send -a "<App>"`).
- **Reload Authority**: QuickShell reloaded only via IPC (`quickshell ipc -p ~/.config/hypr/scripts/quickshell/Shell.qml call main forceReload`) or `qs_manager.sh reload`.
- **QuickShell Process Ownership**: Startup, reload, and the full-shell toggle all pass through `qs_manager.sh`; an operation lock serializes commands, and a separate process-lifetime `flock` prevents a replacement `Shell.qml` from overlapping its predecessor. Process matching is scoped to the shell QML path.
- **IPC and Lock Deadlines**: Scripted `hyprctl` and `quickshell ipc` calls use `timeout`; this includes profile/mode handlers, monitor tools and collectors, sunset restore, and timer popup activation. State, settings, audio, layout, monitor-intent, and power locks have bounded acquisition; wallpaper replacement has a 30-second maximum lock wait. Monitor refresh resolves output state before its single compositor eval, so no script performs nested Hyprland IPC from inside an eval.

## 3. Wallpaper Subsystem Pipeline
- **Wallpaper Carousel Selection Stability**: In `WallpaperPicker.qml`, inotify state updates on `current_wallpaper.txt` skip re-focusing when the currently focused item already matches the applied wallpaper or when `isApplying` is active. On widget open, `targetWallName` is refreshed directly from active wallpaper state. Focus positioning aligns with `preferredHighlightBegin` via `ListView.Center` to cleanly integrate with `StrictlyEnforceRange`. Canonical category names and `.gif`/video formats are properly resolved.
- **Pipeline Routing**:
  - Animated GIFs and video files (`mp4`, `mkv`, `mov`, `webm`, `gif`) route to `mpvpaper` with auto-pause (`-p`), hardware VA-API video decode (`--hwdec=auto-safe`), and background `.mp4` caching in `~/.cache/converted_gifs/` (starts in <0.15s).
  - Static images (`png`, `jpg`, `jpeg`, `webp`) route to `awww img` with `--filter Bilinear`, `--outputs "$OUT_JOINED"`, and `--transition-type none` (<0.1s apply).
- **Systemd Service Architecture**:
  - `awww-daemon.service`: Launched with `--no-cache --format argb` to prevent unbounded raw frame disk cache accumulation.
  - `mpvpaper@<out>.service`: Per-output templated unit consuming `%h/.local/state/mpvpaper/%i.env` with `%i` (verbatim output name, preserving dashes).
- **Wallpaper Kill & Modes Engine**:
  - Managed by `mode_ctl.sh` as the order-independent Single Source of Truth (`$DESKTOP_STATE_DIR/modes/modes.json`).
  - Wallpaper kill turns off wallpaper surfaces and compositor blur/shadow, and sets solid window opacity (`opacity_solid = true`).
  - Restoring recovers transparent window glass and active wallpaper dynamically without `hyprctl reload`.
  - In `rules.lua`, `is_solid_mode()` strictly trusts `modes.json`, eliminating fallthrough to stale QuickShell state files when `modes.json` is present.
  - Symmetrical `window.open` hook dispatches `opaque = 1` in Solid Mode and `opaque = unset` in baseline mode, preventing newly mapped windows from inheriting false-solid opacity.
  - Boot state synchronization (`restore_state.sh`) runs `mode_ctl.sh apply` with `FORCE_APPLY=1` to guarantee active window properties and client configs (`alacritty-colors.toml`) match computed mode state on cold start without state transitions.
- **Carousel & Keybind Cycling Parity**:
  - Keybind cycler (`cycle_wallpaper.sh`) adheres to the active category filter in `${XDG_STATE_HOME:-$HOME/.local/state}/desktop/quickshell/state.json` (`ui.wallpaperFilter`) with fallback to `picker_filter.txt`, filtering candidates with circular index wrapping.
  - QuickShell `WallpaperPicker.qml` watches `current_wallpaper.txt` via `activeWallWatcher` and `lastWallWatcher`, dynamically keeping the carousel centered on the active wallpaper and switching category filters automatically if external cycling moves outside the current filter.


## 4. Audio & Media Pipeline
- **Native PipeWire Unified 10-Band Equalizer & Karaoke Filter-Chain**: Audio configuration is owned by `modules/home/audio.nix`. Its PipeWire `libpipewire-module-filter-chain` provides the equalizer sink and in-graph spectral karaoke effect; the base preset matches `karaoke.sh` (`Depth=0.99`, low cutoff `100 Hz`, air depth `0.05`, transient protection `0`, release `40 ms`, reverb duck `0 dB`).
- **Karaoke & Equalizer UI State Authority**: Equalizer presets maintain raw untweaked audio when 'Off' is selected (0 dB across all 10 bands, unity transfer function $H(z)=1$, bit-perfect pass-through) with strict binary (0/1) Karaoke state integration. In `MusicPopup.qml`, interactive sliders enforce `focusPolicy: Qt.NoFocus` so keyboard Left/Right arrows cleanly cycle equalizer presets without stealing focus.
- **Automatic Handover, Zero Speaker Leak & Physical Sink Cycling**: EQ sink passively forwards audio to the highest-priority physical endpoint automatically (external devices priority 2150; internal speakers priority 1000). WirePlumber setting `device.routes.mute-on-alsa-playback-removed = false` prevents laptop speakers from being muted upon headphone/Bluetooth disconnect. Internal speaker rule `node.drain-on-empty = false` alongside `session.suspend-timeout-seconds = 0` eliminates buffer draining and prevents split-second speaker audio bursts on unplug. Endpoint cycling (`cycle_audio_sink.sh`) reparents `effect_output.eq10` via `pw-link` without setting physical nodes as the global default sink, protecting WirePlumber virtual sink routing.
- **Bluetooth AAC stereo, BudsLink & Dynamic Device Reporting**: WirePlumber rule `bluetooth.autoswitch-to-headset-profile = false` prevents AVDTP codec renegotiation crashes, locking high-quality A2DP stereo. UI widgets (`music_info.sh`, `bluetooth_panel_logic.sh`) resolve playback device and active profile dynamically from `pw-link -l` and `pw-dump Node`/`Device`, accurately reflecting physical targets (e.g. OnePlus Nord Buds 3 vs Laptop Speaker) in both playing and stopped states while guarding against already-paired BlueZ connect errors. Earbud hardware features (ANC, Transparency, per-earbud/case battery levels, and gestures) are managed via native `budslink` (`~/Projects/flakes/budslink-flake`) over BlueZ vendor GATT/RFCOMM sockets.
- **WebRTC Microphone Denoising**: `libpipewire-module-echo-cancel` with `monitor.mode = true` binds to the microphone array, cancels speaker playback acoustic bleed from `effect_input.eq10:monitor`, and publishes `echo_cancel_source` at priority 2100 with zero daemon overhead.
- **Multi-Output Audio Broadcast**: `Super + Ctrl + V` (`toggle_multi_sink.sh` / `pw-broadcast`) dynamically broadcasts equalizer output across all connected external endpoints simultaneously via sub-2ms `pw-link` graph connections, auto-compensating Bluetooth buffer latency (340ms) on wired channels.
- **MPV MPRIS Integration**: `mpv` overridden with `mpvScripts.mpris` symlinked to `~/.config/mpv/scripts/mpris.so` to broadcast D-Bus `org.mpris.MediaPlayer2` signals.
- **WirePlumber Diagnostic Audit**:
  - `mod.rt`: `failed to set realtime policy: Operation not permitted` in journal indicates user session lacking `RLIMIT_RTPRIO` / RTKit permissions; falls back to standard nice scheduling with no dropouts, addressable via `security.rtkit.enable = true`.
  - `m-mpris`: `failed to get DesktopEntry` occurs when browser instances (Brave/Chromium) register dynamic MPRIS D-Bus interfaces with instance PIDs without static `.desktop` file matches; benign telemetry warning.
- **Imperative `pw-link` Scripts & Declarative Migration Plan**:
  - *Current Imperative Scripts*:
    - `cycle_audio_sink.sh`: Queries `pw-link -i` / `pw-link -l`, tears down links with `pw-link -d`, connects `effect_output.eq10` to next physical sink with `pw-link`, and sets default via `wpctl set-default`.
    - `pw-broadcast` (`toggle_multi_sink.sh`): Queries external endpoints via `pw-link -i`, unlinks internal speaker via `pw-link -d`, launches dynamic `pw-loopback` unit with `--delay 0.340`, and wires `effect_output.eq10` to both Bluetooth and loopback nodes.
  - *Declarative Replacement Architecture*:
    - Sink Cycling: Migrate to pure WirePlumber session management (`wpctl set-default <id>`). With `linking.follow-default-target = true` and `linking.allow-moving-streams = true`, WirePlumber automatically reparents passive filter-chain outputs (`effect_output.eq10`) without explicit `pw-link` surgery.
    - Multi-Sink Broadcast: Define declarative `libpipewire-module-combine-sink` or static `libpipewire-module-loopback` in `pipewire.conf.d/`. WirePlumber policy node matching routes `effect_output.eq10` into the broadcast distributor.
    - EQ Priority Invariant: Master virtual sink `effect_input.eq10` strictly retains priority 2200; broadcast/delay filters sit strictly downstream between `effect_output.eq10` and physical sinks (priority 2150/1000), preventing double-filtering and preserving single-point volume authority.

## 5. Power & State Management Design
- **State Directory Invariant**:
  - Persistent desktop state lives strictly in `${XDG_STATE_HOME:-$HOME/.local/state}/desktop/` (subdivided by area: `wallpaper/`, `power/`, `audio/`). State writes must be atomic (`tmp` file + `mv -f` in the same directory).
  - Regenerable cache files belong in `~/.cache`.
  - *Persistent State Unified*: All persistent state migrated to `${XDG_STATE_HOME:-$HOME/.local/state}/desktop/` (`quickshell/state.json`, `power/profile`, `modes/wallpaper_killed`, `modes/gaming_mode`, `recording/rec_pid`, `wallpaper/current_wallpaper.txt`). Legacy cache locations purged.
- **Race-to-Sleep Strategy**: Maximize package C-state sleep ($C8/C10$) by bursting tasks at full frequency and sleeping immediately. Use event signals where possible and keep intentional accounting/sample intervals coarse and bounded.
- **Coffee Mode & Persistent Idle Inhibition**:
  - `SUPER + F2` invokes `power.sh inhibit` to acquire `systemd-inhibit --what=idle:sleep --who=idle-inhibit-toggle --why="Coffee mode (idle inhibit)" --mode=block sleep infinity`.
  - `restore_state.sh` checks state and automatically re-engages the inhibitor across QuickShell reloads, Hyprland restarts, and cold boots until explicitly toggled off.
  - In `hypridle.conf`, idle timers lock at 120s, turn DPMS off at 130s, and suspend at 1800s (30m) with `ignore_dbus_inhibit = false` and `ignore_systemd_inhibit = false`.
- **Continuous Battery Drainage Pattern Analyzer (`battery_audit.sh`, `power.sh battery-audit`)**:
  - Selects the first battery supply discovered under `/sys/class/power_supply/` and samples its power reading every 60s during discharge; elapsed timestamp deltas drive interval totals.
  - Per-app Watt-hour attribution is modeled from proportional CPU-time deltas; it is not measured per application.
  - Detects power surges ($>16\text{W}$) with timestamps and offending processes.
- **Hardware Power Policy (`modules/system/power.nix`, `hosts/<host>/system.nix`)**:
  - NVMe APST enabled (`NVME_APST_CHAR_ENABLE_ON_BAT = 1`), allowing PCIe Gen4 SSD to drop into autonomous low-power states (<50mW) when idle.
  - The personal `user.power.disableNmiWatchdog` preference controls both `nmi_watchdog=0` and TLP's `NMI_WATCHDOG = 0`; it is enabled to preserve current behavior and is not a battery-only setting.
  - Process packing (`SCHED_POWERSAVE_ON_BAT = 1`) packs background tasks onto fewer cores so unused cores remain asleep.
  - Intel GPU battery frequency settings are emitted only when generated host facts identify Intel graphics and provide supported frequency bounds.
  - One `user.nix` workaround flag derives both TLP USB autosuspend and `usbcore.autosuspend=-1`, preventing them from drifting apart. Sonix FHD webcam (`3277:0022`) is guarded via TLP `USB_DENYLIST`, udev power/control lock, and `uvcvideo nodrop=1`.
  - The Power Saver TLP profile keeps platform profile `balanced` to preserve the intended fan behavior; `power.sh profile` makes no direct ACPI or vendor-CLI writes.
  - Passwordless `tlp` profile/start commands are declared beside the TLP service and only on hosts with a detected battery. Audio recovery keeps its exact modprobe allowlist in `modules/system/users.nix`.
  - Batteryless hosts skip TLP hardware profile calls while keeping compositor profile state and monitor refresh handling available.
- **Display Power Policy & Serialized AC Power Transitions**: `refresh_monitor.sh` reads Hyprland `availableModes` outside the compositor eval, then sends one `hyprctl eval` containing only the resolved `hl.monitor()` call. Startup, explicit profile changes, and power-supply events call the same script. It never launches a nested `hyprctl` request from inside `hyprctl eval`, avoiding the compositor IPC stall found in the live unit logs. The single saved intent at `$DESKTOP_STATE_DIR/monitors/intent.json` owns resolution, scale, transform, layout, and placement; power policy changes only refresh and does not re-enable a disabled panel.
  - *AC Power Pipeline Serialization*: `power.sh profile` takes a bounded exclusive lock on `/run/user/$UID/desktop-power.lock` while applying TLP and persisting profile state, then releases it before calling `mode_ctl.sh`. This prevents inversion with `mode_ctl.sh`'s mode lock; both lock acquisitions are bounded. A systemd user timer coalesces udev power-supply bursts for 500ms before running `power.sh auto`. `refresh_monitor.sh` has its own bounded lock and every Hyprland IPC call has a timeout. Hardware profile switches skip redundant TLP executions when matching `$DESKTOP_STATE_DIR/power/applied`.
- **Input Device Permissions**: `/dev/uinput` uses mode `0660` with the seat ACL (`TAG+="uaccess"`); direct membership in the broad `input` group is not required by repository services. Lid-event access remains a device-specific uaccess rule.
- **Wi-Fi Failover**: The connectivity dispatcher compares a visible candidate SSID with the SSID stored in each saved wireless profile; NetworkManager profile display names are not assumed to equal SSIDs.
  - NetworkManager connectivity check interval set to 300s, eliminating 30s periodic Wi-Fi radio and CPU wakeups.

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
- **Multi-Monitor Workspace Separation (macOS Spaces Model)**:
  - Each monitor dynamically owns a dedicated 10-workspace block derived at runtime from monitor order in Lua (`keybinds.lua`).
  - `SUPER + 1..0` focuses the Nth workspace of the currently focused monitor; `SUPER + SHIFT + 1..0` moves the active window to the Nth workspace of that monitor.
  - `SUPER + CTRL + Left/Right` shifts relative to the focused monitor (`m-1`/`m+1`). Single-monitor or mirrored setups use a single unified 1..10 workspace block.
- **HiDPI Toolkit Scaling**: `GDK_SCALE = "2"`, `QT_AUTO_SCREEN_SCALE_FACTOR = "1"`, `QT_ENABLE_HIGHDPI_SCALING = "1"` in `env.lua`. Chromium download bubbles disabled in favor of in-window progress to avoid detached subsurface coordinate misplacement.
- **Dynamic Scrolling Ribbon Architecture (`scrolling.lua`, `toggle_layout.sh`)**:
  - Toggled atomically via `SUPER + F10` between Dwindle and Scrolling layouts.
  - Native space-filling scaling: 1 window takes 100% full scale (`fullscreen_on_one_column = true`); 2 windows split side-by-side filling the usable screen ($x = 52\text{px}$ or $12\text{px}$ to $x = 1428\text{px}$) without centering; 3+ windows open along the continuous scrolling ribbon with free touchpad swipe (`move_snap_to_grid = false`) and mouse wheel navigation (`SUPER + ALT + Wheel`).
  - Unified across all workspaces: Special workspaces (`special:magic`, `special:music`) follow the exact same space-filling and left-margin pinning rules without centering or window squashing.
  - **Dynamic Neighbor Sizing (Dwindle Mode Parity)**: Resizing any window via keyboard (`SUPER + SHIFT + Left/Right`), mouse wheel (`SUPER + SHIFT + Wheel`), or mouse drag release (`SUPER + X` / `SUPER + RMB`) dynamically adjusts adjacent neighbors to fill the screen flush to monitor margins (52px or 12px) with zero empty void and zero unwanted centering.
  - **Cross-Mode Layout Memory**: Window geometries and custom proportions are captured to `$STATE_DIR/ws_<id>_<mode>.json` across `SUPER + F10` layout toggles. Switching from Dwindle preserves split ratios in Scrolling (and stacks vertical pairs into single columns), and switching back restores exact Dwindle split sizes rather than resetting to 50/50.
  - **Niri-Style Ribbon Framing (`focus_fit_method = 1`, `follow_focus = 0`)**: Focus never forces windows to center or shifts ribbon position unexpectedly. On-screen side windows remain completely static when clicked or focused (`follow_focus = 0`), allowing seamless interaction with sidebars and side-by-side windows without jumping. Off-screen columns slide smoothly to the nearest viewport edge only when navigated to.
  - **Bounded Ribbon Margins & Free Scrolling**: Touchpad 3-finger horizontal swipe and mouse wheel navigation provide smooth, unbounded continuous tape scrolling without static column grid snapping. Ribbon navigation stops strictly at the left margin (52px with left bar, 12px with top bar) on lifecycle events without resetting the user's active viewport position.
  - **Cursor Focus Stability (`cursor:no_warps = true`)**: Programmatic focus changes and layer shell interactions never warp or jerk the mouse pointer across windows, ensuring consistent, predictable cursor behavior across workspace and ribbon navigation.
  - **Fullscreen Scrolling Inhibit & Layout Dispatch Guarding**: When any window is in fullscreen mode, 3-finger horizontal gestures (`hl.gesture unset`), mouse wheel ribbon navigation, and smart resizing are completely suppressed. All layout-specific dispatches (`inhibit_scroll`, `colresize`, and `move`) are strictly gated by `is_scrolling_layout()`, completely isolating non-scrolling layouts (e.g. Dwindle) from invalid layoutmsg dispatches and eliminating runtime error notification banners.
  - Scale recovery on close ($3+ \rightarrow 2 \rightarrow 1$) operates natively via `layoutmsg fit all` hooked to `window.destroy`, eliminating imperative resize hacks, left-side void space, and collapsed sliver surfaces.

## 7. Operational Discipline & Safety Rules
- **Intel GPU Ring Protection**: Minimum 1.5s separation between manual visual mode test steps to prevent integrated GPU `rcs0` execution ring saturation and Aquamarine DRM page-flip crashes (`CHyprOpenGLImpl::begin` assertion failure -> `SIGABRT` -> Safe Mode). Product code drops overlapping requests while a transition is in flight.
- **Lockscreen Ban**: Never execute or test `Lock.qml` directly or autonomously (desynchronizes PAM session state and locks the user out).
- **Workspace Protection**: Never delete files or directories inside `~/Projects/` or its subfolders.
- **Safe Rebuild Pipeline**: Use `rebuild` to stage tracked changes, commit, build, switch, and run the health check. A critical health failure triggers rollback. The first installation uses the labeled manual `nixos-rebuild switch --flake` path before the helper exists.
- **Battery-First Balanced Option**: `user.power.balancedBatteryFirst` enables battery-first tuning (defaults to `false`, enabled in `user.nix`). Turning it on sets Balanced-on-battery EPP to `power`, disables CPU boost on battery, and caps Intel GPU battery boost to 1100 MHz (preventing exponential power draw above the 10nm voltage wall); Power Saver and AC behavior remain unchanged. This trades peak burst clock for lower CPU/GPU energy use on battery.
- **Monitor Mode Selection**: The monitor widget and refresh service query active Hyprland outputs and their advertised modes at runtime. The old static eDP-1 mode list in `settings.json` was unused and removed; current machine panel details remain in `hosts/nixos/PERSONAL.md`.
- **Home Manager Launchers**: Brave and OnlyOffice wrappers reference their selected Nix package outputs directly instead of assuming `/run/current-system/sw/bin` paths.
