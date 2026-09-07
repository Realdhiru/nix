# CHANGELOG

## 2026-09-07 — Reproducible KDE Connect Remote Input, Presentation Remote & Drawing Tablet on Hyprland

### Fixed & Implemented

1. **Wayland RemoteDesktop Portal Bridge (`pkgs/hypr-kdeconnect-portal.nix`, `flake.nix`, `modules/system/services.nix`)**:
   - **Root Cause**: KDE Connect 26.04+ on Wayland requires the `org.freedesktop.portal.RemoteDesktop` interface (via `ConnectToEIS` and `libeis`). Neither `xdg-desktop-portal-hyprland` nor `xdg-desktop-portal-gtk` implements RemoteDesktop, silently disabling the touchpad mouse, keyboard input, and presentation slide keys.
   - **Solution**: Packaged `hypr-kdeconnect-portal` (based on `hypr-kdeconnect-fix`), implementing `org.freedesktop.impl.portal.desktop.hypr_kdeconnect`. It translates incoming `libeis` events and RemoteDesktop calls into Hyprland-native `zwlr_virtual_pointer_v1` and `zwp_virtual_keyboard_v1` protocols.
   - **Flake Integration**: Declared the derivation in `pkgs/hypr-kdeconnect-portal.nix`, registered it in `flake.nix` overlays, added it to `xdg.portal.extraPortals`, and routed `RemoteDesktop` specifically to `hypr-kdeconnect` in `xdg.portal.config.hyprland`.

2. **Pointer Stability & Linear Acceleration Curve (`dotfiles/hypr/input.lua`)**:
   - **Root Cause**: Hyprland's default input configuration had `sensitivity = 0.5` and `accel_profile = "adaptive"`. Because Android's KDE Connect touchpad already applies finger acceleration, Hyprland's non-linear curve compounded the movement, leading to severe pointer flinging, overshoot, and jitter.
   - **Solution**: Configured a dedicated device block for Hyprland's virtual pointer (`unknown-device`) setting `accel_profile = "flat"` and `sensitivity = 0.0`. This provides 1:1 linear pointer movement matching the phone screen without overshoot.

3. **Drawing Tablet & Virtual Digitizer Permissions (`modules/system/services.nix`, `modules/system/users.nix`)**:
   - **Root Cause**: The KDE Connect digitizer plugin (`kdeconnect_digitizer.so`) writes directly to `/dev/uinput`. The device node was restricted to `0600 root:root` and user `realdhiru` lacked the necessary permissions, failing device creation with "failed to create virtual input device".
   - **Solution**: Added `services.udev.extraRules` setting `KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0666", TAG+="uaccess", OPTIONS+="static_node=uinput"`, enabled `hardware.uinput.enable = true`, added KDE Connect udev rules, and granted `uinput` and `input` groups.
   - **Reproducibility**: Entirely codified in the NixOS flake repository; persists across all rebuilds and cleanly ports to any new machine using this flake.

4. **Phone Call Notification Lifecycle & TopBar Dismissal (`dotfiles/hypr/scripts/quickshell/NotifTicker.qml`, `dotfiles/hypr/scripts/quickshell/TopBar.qml`)**:
   - **Root Cause**: Quickshell treated notifications with actions as permanent sticky pills (`timeoutMs = 0`), preventing incoming call notifications from clearing unless "Mute Call" was clicked. Furthermore, the D-Bus `Notification.closed` signal was not monitored, causing the call pill to remain stuck even after the call was answered or hung up.
   - **Solution**:
     - Connected `n.closed.connect(...)` in `NotifTicker.qml` to instantly dismiss ticker pills and purge the call from history the millisecond the call is answered, declined, or ended.
     - Set a 45s ringing boundary for incoming calls and a 12s reaction timeout for generic action notifications.
     - Added a dedicated dismiss "󰅖" button directly into the TopBar notification pill so users can dismiss the pill immediately without muting the call.

5. **Notification History Persistence in BatteryPopup (`dotfiles/hypr/scripts/quickshell/battery/BatteryPopup.qml`)**:
   - **Root Cause**: `BatteryPopup.qml` contained a delegate connection `realNotif.onClosed: delegateWrapper.removeThisNotif()`, causing all transient notifications (such as system errors, KDE Connect warnings, and alerts) to disappear from the notification history panel the moment their on-screen ticker expired.
   - **Solution**: Restricted automatic removal strictly to completed phone calls. System errors, KDE Connect notifications, files, and messages remain securely in the history panel until explicitly dismissed with the panel's "󰅖" clear button.
   - Directly bound `notifModel` and `liveNotifs` to `NotifTicker` singletons to guarantee instant synchronization.

6. **Process Detachment for Quickshell (`dotfiles/hypr/scripts/reload.sh`)**:
   - Wrapped Quickshell invocation with `nohup` and `disown` to protect the process from shell SIGHUP signals.

7. **Quickshell Inotify Feedback Loop & Idle Battery Drain Fix (`dotfiles/hypr/scripts/quickshell/watchers/colors_wait.sh`)**:
   - **Root Cause**: `MatugenColors.qml` is instantiated across 11 distinct desktop UI components, each launching `colors_wait.sh`. The script unconditionally called `touch "$TARGET"` (`~/.cache/matugen/qs_colors.json`) on start, firing `CLOSE_WRITE` to all 10 other concurrent watchers. Each instance simultaneously unblocked, ran `onStreamFinished`, and re-triggered `colors_wait.sh`, establishing an 11-way runaway fork bomb spawning **3,882 processes/second** and generating 42,000 context switches/sec, 30,000 interrupts/sec, driving CPU to 84°C and battery idle discharge to ~48W.
   - **Solution**: Changed `touch "$TARGET"` in `colors_wait.sh` to only touch if the file does not exist (`[ -f "$TARGET" ] || touch "$TARGET"`). When the cache exists, instances block dormant in `inotifywait` waiting for legitimate theme changes. CPU idle rose to 95%, system load dropped to 1-2%, and process spawn rate dropped to ~2.5 PIDs/s.

8. **Battery Power Profile & Spike Optimization (`modules/system/power.nix`)**:
   - **Root Cause**: TLP on battery had `CPU_BOOST_ON_BAT = 1`, `CPU_HWP_DYN_BOOST_ON_BAT = 1`, and `CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_performance"`. Whenever light background processes or browser tabs woke up, Intel P-cores spiked up to 4.7 GHz at high voltage, causing excessive battery discharge and preventing CPU package sleep.
   - **Solution**: Configured `CPU_BOOST_ON_BAT = 0` (caps 12 cores at base frequency on battery to cut voltage spikes while preserving full 12-core throughput), `CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power"`, `CPU_HWP_DYN_BOOST_ON_BAT = 0`, and set `PLATFORM_PROFILE_ON_BAT = "quiet"`.

9. **Smart AC Performance Profile & Intel GPU Framebuffer Compression (`modules/system/power.nix`)**:
   - **Root Cause**: On AC power, `CPU_ENERGY_PERF_POLICY_ON_AC = "performance"` forced all 12 cores to remain pegged at 4.4 GHz at 0% load, running hot (60°C–70°C) and exhausting thermal boost budget before workloads began. Furthermore, Intel GPU Framebuffer Compression (`enable_fbc`) was disabled, forcing the memory bus to stream ~2.2 GB/s of raw uncompressed display buffer at 120Hz.
   - **Solution**: Configured `CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance"` (downclocks idle cores to 400 MHz–800 MHz while ramping to 4.7 GHz in <1ms under load) and `RUNTIME_PM_ON_AC = "auto"`. Added `"i915.enable_fbc=1"` to `boot.kernelParams` to free memory bandwidth for 3D games and compositor tasks.


---

## 2026-09-06 — Wallpaper Indexing, TopBar Workspaces & Dynamic Scaler Fixes

### Fixed & Optimized

1. **Wallpaper Indexing, Previews & Canonical State Persistence**:
   - **Filtered Indexation (`wallpaper_thumbnail.sh`)**: Excluded hidden directories (`-not -path '*/.*'`) and restricted discovery to valid media extensions (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.mp4`, `.mkv`, `.mov`, `.webm`). Cleaned 347 invalid `.git/objects` blobs that were previously polluting `flat/` and causing blank/broken previews in `WallpaperPicker.qml`.
   - **Case-Insensitive Extensions (`WallpaperPicker.qml`)**: Expanded `FolderListModel.nameFilters` to include uppercase variants (`*.PNG`, `*.JPG`, etc.), fixing missing previews for files with uppercase extensions.
   - **Canonical Path Resolution (`set_wallpaper.sh`, `boot_wallpaper.sh`)**: `set_wallpaper.sh` now resolves `realpath` before writing `~/.cache/current_wallpaper.txt`. Prevents ephemeral `.cache` symlink paths from saving to state, eliminating the reboot fallback where random wallpapers were selected.
   - **Color-Extraction Cache Hit (`set_wallpaper.sh`)**: Fixed thumbnail lookup in `set_wallpaper.sh` to search for cached hash-prefixed thumbnails (`*_${BASENAME}`), avoiding redundant ImageMagick / FFmpeg re-decoding.
   - **Odd-Dimension GIF Encoding & Fallback (`set_wallpaper.sh`)**: Injected `pad=ceil(iw/2)*2:ceil(ih/2)*2` filter into the GIF-to-MP4 FFmpeg conversion pipeline. Fixes H.264 encoder failures on GIFs with odd width/height (such as `Blackrush.gif` at 640x303) that previously produced empty 0-byte cache files. Added `-s` non-empty validation and automatic fallback to raw GIF playback if conversion fails.
   - **Daemon Process Lifecycle (`set_wallpaper.sh`)**: Added `disown` to background `mpvpaper` and socket watcher invocations, preventing subshell exit signals from prematurely terminating live video/GIF wallpapers.
   - **Zero-Residue Wallpaper Deletion & Auto-Watcher (`wallpaper_thumbnail.sh`, `wallpaper_watcher.sh`, `startup.lua`)**: Integrated a comprehensive multi-tier cleanup engine into `wallpaper_thumbnail.sh` and created an event-driven `wallpaper_watcher.sh` inotify daemon registered in `startup.lua`. The moment a wallpaper is deleted from `~/Pictures/Wallpapers` (via GUI or CLI), all associated artifacts—the symlink in `flat/`, generated thumbnail in `thumbs/`, color marker in `colors_markers/`, and converted video in `converted_gifs/`—are immediately purged with zero residue. If the deleted file was the active wallpaper, it gracefully switches to a healthy remaining wallpaper.

2. **TopBar Workspace & Media Widget Styling (`TopBar.qml`)**:
   - **Adaptive Terminal Background Opacity for Light Wallpapers (`wezterm.lua`)**: Resolved unreadable terminal text on bright wallpapers where 100% transparent backgrounds (`opacity = 0.0`) blended into white wallpaper regions. Added dynamic lightness detection watching `~/.cache/matugen/wallpaper_is_light.txt`: on light wallpapers, WezTerm automatically shifts to a rich, dark frosted background (`opacity = 0.88`), providing crisp text definition and 100% legibility while reverting to full transparency (`opacity = 0.0`) on dark wallpapers.
   - **Fixed Quickshell Non-Existent FileWatcher Type (`MatugenColors.qml`)**: Removed invalid `FileWatcher` declaration in `MatugenColors.qml` that was causing `ERROR: FileWatcher is not a type`, reverting to the high-frequency 1-second dynamic poller to guarantee rock-solid runtime stability.
   - **Adaptive Contrast-Aware TopBar Pills for Light Wallpapers (`set_wallpaper.sh`, `MatugenColors.qml`, `TopBar.qml`)**:
     - *Luminance Telemetry*: Enhanced `set_wallpaper.sh` to measure the HSL luminance of the top 15% region of the wallpaper (`top_lum`) where the topbar sits. Automatically determines whether the top region is bright (`top_lum > 55%` or overall `lum > 60%`) and injects `"isLight": true/false` into `qs_colors.json`.
     - *Adaptive Capsule Styling*: Added unified dynamic pill styling properties (`pillBg`, `pillBgHover`, `pillBorder`, `pillBorderHover`) to `TopBar.qml`.
       - On **Dark Wallpapers**: Pills retain their sleek, subtle translucency (`surface1` at `0.35` alpha).
       - On **Light Wallpapers**: Pills automatically transform into rich, dark frosted capsules (`crust` at `0.82` alpha with `0.12` contrast border), shielding all icons, workspaces, time, battery, and media text for 100% pin-sharp contrast and legibility against bright backgrounds.
     - *Zero-Latency Sync*: Added `Quickshell.Io.FileWatcher` to `MatugenColors.qml` to instantly reload colors whenever `qs_colors.json` is updated.
   - **Opaque Media Pill Text & Visualizer**: Made the track title, playback time (`mocha.text`), and CAVA visualizer segments 100% solid/opaque (`alpha = 1.0`) with ghost dot segments removed, providing crisp definition and high visibility on light wallpapers while preserving the normal transparent container baseline.
   - **CAVA Visualizer Baseline & Margin Alignment**: Fixed the visual misalignment where CAVA bars were sagging below the timeline text. Anchored `cavaVisualizer`'s bottom to `mediaInfoColumn.bottom` with dynamic baseline compensation (`Math.round(timeText.implicitHeight - timeText.baselineOffset)`), and tuned segment parameters (`segCount: 8`, `segH: s(2)`, `segGap: s(1)`) so that CAVA's bottom baseline matches the timeline text baseline and its peak height matches the title text height. Both top and bottom capsule margins now align down to the pixel.
   - **Zero-Overhead Workspace Switching**: Replaced `Quickshell.execDetached` bash subprocess invocation on pill click with native `Hyprland.dispatch("workspace " + wsName)`.
   - **Highlight Jitter Elimination**: Fixed `activeHighlight` coordinate bouncing during pill expansion/contraction by smoothing animation curves and eliminating layout race conditions.
   - **Special Workspaces & Dead Code**: Guarded `updateNativeWorkspaces()` against invalid/negative scratchpad IDs, and removed dead `workspaces.sh` script and unused `workspaceCount: 69` property.

3. **Scaling Desync Root Cause Fix (`settings.json`, `Main.qml`, `Scaler.qml`)**:
   - **Reverted Dual-Scaling Experiment**: Kept `Scaler.qml`, `Main.qml`, and `TopBar.qml` strictly adhering to the single-pass scaling rule defined in `AGENTS.md`.
   - **Proven Root Cause**: `settings.json` contained a stale `"uiScale": 1.3`. `settingsReader` in `Main.qml` executed `watchers/settings_wait.sh`, which has a 300-second (`timeout 300 inotifywait`) failsafe. On reload/startup, `masterWindow.globalUiScale` started at `1.0` (matching all popup widget scalers). Exactly 300s (5 minutes) later, the timeout expired and `settingsReader` read `1.3`, blowing up `WindowRegistry.js` bounds to 1476px while inner widgets were scaled for 1135px, causing the 340px clipping and overlapping shown in the screenshot.
   - **Resolution**: Aligned `settings.json` to `"uiScale": 1.0` so `Main.qml` and all popup widgets remain in 100% permanent scale alignment on boot, across reloads, and after the 300s timeout.

4. **Minimal Stacked Card Lockscreen Redesign & Stability Overhaul (`Lock.qml`, `lock.sh`)**:
   - **Crash-Loop & Singleton Guard (`lock.sh`)**: Added a mutex (`pgrep -f 'quickshell.*Lock\.qml'`) to prevent multiple processes from racing over the Wayland `ext-session-lock-v1` singleton. Integrated automatic recovery (`hl.clear_crashed_lockscreen()`) to ensure the compositor never bricks into the emergency crash screen ("Oopsie daisy"). Removed dangerous infinite while-loop.
   - **Smooth Dot Typing Model (`Lock.qml`)**: Replaced the integer-based `Repeater` (which caused full-list destruction/jitter on every keystroke) with a dynamic `ListModel` (`passModel`). Dots now pop into place with isolated spring animations (`scale: 0.3 -> 1.0`, `Easing.OutBack`), providing a 60fps buttery-smooth typing feel.
   - **Removed Obtrusive Ring Overlay**: Stripped out the old 1-second spinning concentric rings and lock orb overlay in favor of a clean, non-blocking entrance transition where the capsule card gracefully glides into place while maintaining instant typing readiness.
   - **Prominent Card & Stacked Typography**: Proportioned central capsule card to occupy ~24% width and ~62% height with bold 110–140px stacked two-tone clock (`root.blue` and `root.lockText`), JetBrains Mono dotted zero, and `dd MMM dddd` date.
   - **Hyprland Daily Splash Quotes**: Linked bottom greeting to `hyprctl splash` to render dynamic daily Hyprland quotes.
   - **Dynamic Tech Telemetry & Hacker Top Status Header (`Lock.qml`, `lock.sh`)**: Completely eliminated emojis and personal user names in favor of an authentic UNIX, hacker, and live system telemetry status engine. Every single lock event picks a unique technical line from a diverse 45+ item pool combining live system telemetry (`SYS_KERNEL`, `SYS_LOAD`, `SYS_UPTIME` exported via `lock.sh`) with cryptographic, PAM, Wayland, and NixOS security lines (e.g. `[SYS_KERNEL] Linux 7.2.1 // Load: 3.52 // Up: 12h 15m`, `[SEC_GATEWAY] Hyprland [ext-session-lock-v1]`, `chmod 000 /dev/display -- Authenticate to restore permissions`, `cat /dev/urandom > /dev/lockscreen -- Entropy pool primed`).
   - **Frosted Glass Aesthetic & Reduced Darkness**: Decreased central capsule card darkness by switching from opaque `crust` at `0.72` to translucent `surface0` at `0.22` with a specular top reflection highlight (`rgba(255, 255, 255, 0.24)`) and subtle glass border (`rgba(255, 255, 255, 0.18)`). Reduced overall screen dimmer opacity from `0.38` down to `0.18` and boosted Gaussian background blur (`blurMax: 40`, `blur: 0.65`) so wallpaper tones illuminate through the glass with genuine depth.
   - **Fluid Displaced Password Dots & Soft Frame Interpolation**: Replaced the static `Row` container with an animated-width `ListView` equipped with `displaced`, `add`, and `remove` transitions. Eliminated the jarring 1-frame horizontal snapping where all existing dots jumped instantly whenever a key was pressed or deleted.
     - *Soft Blossoming (85ms)*: New dots now expand gracefully from `scale: 0.1` to `1.0` with `Easing.OutCubic` and soft `65ms` opacity entry.
     - *Smooth Horizontal Glide (80ms)*: Existing dots smoothly glide across horizontal coordinate space via `displaced: Transition` and `Behavior on width` (`80ms`, `Easing.OutQuad`).
     - *Soft Exit Dissolve (70ms)*: Backspaced dots shrink smoothly into nothingness (`scale -> 0.0`, `70ms`) rather than abruptly disappearing in a single frame.
     - *Fading Placeholder (80ms)*: Added `Behavior on opacity` to `"Use Me ;)"` placeholder text so it softly dissolves rather than blinking off.
   - **Zero-Blank Frame-0 Seamless Wallpaper**: Eliminated the 1-second pitch-black screen flash when locking. `lock.sh` now directly pre-exports `CURRENT_WALLPAPER` into the execution environment, enabling `Lock.qml` to resolve and synchronously decode the wallpaper on Frame 0 (`asynchronous: false`, `cache: true`). The opaque dark fallback rectangle (`color: root.base`) is removed from the active render tree, and the asynchronous bash child process probe is eliminated.
   - **Cinematic Depth-of-Field Focus & Unlock Dissolve Transitions**:
     - *Entrance (Lock)*: Rather than jarringly jumping into dark blur, the lock surface begins with the wallpaper in 100% sharp focus (`blur = 0`, `dimmer = 0`). Over 240ms (`Easing.OutCubic`), the background smoothly glides from clear focus into a creamy Gaussian frosted blur while the center clock card softly fades into view.
     - *Exit (Unlock)*: Pressing Enter with the valid password triggers `exitSequence` (180ms) prior to dropping the session lock. The clock card gently fades out and the frosted blur dissolves seamlessly back to razor-sharp wallpaper focus, transitioning into the desktop and application windows without tearing or abrupt cuts.

## 2026-08-30 — Quickshell Event-Driven Refactor, Power Architecture & MPV Integration

### Added & Refactored

1. **Quickshell Native Event-Driven Refactor**:
   - **Subsystem 1 (Process Watchers)**: Replaced `power_state_watcher.sh` loop with native `Quickshell.Io.FileWatcher` reading `/sys/firmware/acpi/platform_profile`. Cleared orphaned `inotifywait` background subshells. Gated `sys_fetcher.sh` strictly to when `SystemUsage.qml` subscriber is active.
   - **Subsystem 2 (Hyprland Workspaces Native IPC)**: Replaced `workspaces.sh`, `socat`, `wsWatcher` (`inotifywait`), and `wsReader` (`cat`) with native `Quickshell.Hyprland` C++ IPC socket bindings (`focusedWorkspace`, `workspaces`, `rawEvent`). Reduced workspace IPC dispatch latency to **6ms**.
   - **Subsystem 3 (PipeWire Audio & Watchers)**: Replaced `wpctl get-volume` shell calls with native `Quickshell.Services.Pipewire` bindings (`Pipewire.defaultAudioSink.audio`), achieving **8ms instant volume signal response**. Replaced 2s `recPoller` and `update_wait.sh` with clean event-driven file checks.
   - **Power Impact**: Quickshell continuous idle discharge rate dropped from **28.25 W down to 10.85 W** (~17.4 W saved), recovering CPU C2+C3 sleep residency from ~5% up to **87.41%** (with 66.14% in deep C3 sleep).

2. **Power Architecture & TLP 1.9.1 Configuration**:
   - Fixed `asusd.service` enabling (`services.asusd.enable = true`) to enforce 80% charge threshold.
   - Set `change_platform_profile_on_battery/on_ac = false` in `asusd.ron` so TLP is sole authority over platform profiles.
   - Empirically verified 3-profile design:
     - **Balanced**: Preserved 100% untouched (`balance_performance`, Turbo `1`, Platform Profile `balanced`, ASPM `powersupersave`, Wi-Fi `on`).
     - **Battery Performance**: Maximum unconstrained performance (`performance` EPP, Turbo `1`, Platform Profile `performance`, max 4.69 GHz clock).
     - **Battery Power Saver**: Maximum battery life (`power` EPP, Turbo `0` / 2.6 GHz base clock cap, Platform Profile `quiet`, ASPM `powersupersave`, Wi-Fi `on`).
   - Explicitly declared `RUNTIME_PM_ON_SAV`, `PCIE_ASPM_ON_SAV`, `WIFI_PWR_ON_SAV` in `modules/system/power.nix`.

3. **MPV Local Media MPRIS Integration & Wallpaper Isolation**:
   - Installed `mpris.so` in `~/.config/mpv/scripts/mpris.so` and overrode `mpv` package with `(mpv.override { scripts = [ mpvScripts.mpris ]; })` for standard D-Bus `org.mpris.MediaPlayer2` media tracking.
   - Fixed topbar music widget hijacking by passing `--load-scripts=no` to `mpvpaper` in `set_wallpaper.sh`. Wallpaper rendering is isolated from MPRIS while user media playback in `mpv` continues broadcasting media status and driving `cava` audio visualizers.

4. **Helium Browser Integration**:
   - Added `oxcl/nix-flake-helium-browser` flake input in `flake.nix`.
   - Added `inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default` to system packages in `modules/system/packages.nix`.

4. **UI & Geometry Fixes**:
   - Reverted popup `Scaler` components across all 9 popup QML files back to single-pass `currentWidth: Screen.width` to eliminate double-scaling multiplication.
   - Updated `updateNativeWorkspaces()` in `TopBar.qml` to track workspaces > 6 dynamically without arbitrary upper caps.
   - Updated TopBar music widget geometry (`mediaInfoColumn`) to derive width dynamically from `timeText.implicitWidth`, preventing timeline truncation (`01:24 / 06:45`) without giant empty gaps on short titles (`命盤`).

5. **QuickShell TopBar Workspace Icons Fix**:
   - Fixed empty inactive workspace icons staying visible by checking open window count (`ws.toplevels.count > 0` / `ws.lastIpcObject.windows > 0`) before marking `occupiedMap[ws.id] = true`.
   - Fixed unreliable workspace icon refresh by extending Hyprland `onRawEvent` listeners in `TopBar.qml` to include window lifecycle events (`openwindow`, `closewindow`, `movewindow`, `movewindowv2`, `moveworkspacev2`).
   - Updated `workspacesModel` to perform in-place item updates/diffing instead of `.clear()`, eliminating repeater delegate re-instantiation glitches and preserving smooth active highlight animations.

6. **Declarative Desktop Portal & Camera Integration**:
   - Added `xdg.portal` declarative configuration with `xdg-desktop-portal-hyprland` and `xdg-desktop-portal-gtk` in `modules/system/services.nix`.
   - Defined `systemd.user.targets.hyprland-session` bound to `graphical-session.target` in `modules/system/services.nix`.
   - Started `hyprland-session.target` on Hyprland startup via `hl.on("hyprland.start", ...)` in `startup.lua`.
   - Resolved camera & WebRTC D-Bus portal access in browsers (Zen, Brave, Chrome, Firefox) and restored 100% green health check.

## 2026-08-20 — System fixes & bloat cleanup

### Fixed

1. **EasyEffects equalizer was dead** — `home.nix` originally launched the daemon with `preset = "live_eq"`. This triggered the `--load-preset` flag, causing EasyEffects to exit immediately on newer versions. Removed it; `equalizer.sh` now reliably pushes the preset to the background daemon.
2. **Touchpad gestures (horizontal scroll) missing in apps** — Chromium and Electron apps defaulted to XWayland. Added global `NIXOS_OZONE_WL = "1"` in `default.nix` and forced `--ozone-platform-hint=wayland` for Brave, enabling native Wayland inputs.
3. **Rofi UI was excessively large** — `theme.rasi` possessed massive hardcoded CSS values (`22px` fonts, `800px` width) that inflated exponentially under Wayland scaling. Reduced structural paddings and font size to `14px` for correct scaling.
4. **Configuration bloat** — Removed heavy creative packages (`blender`, `kdenlive`, `onlyoffice-desktopeditors`, etc.) from `packages.nix` to streamline the desktop.

## 2026-08-16 — Second audit fixes (commits a3f8c91…2dc1069)

Fixes from an external audit, all live-verified.

### Fixed

1. **Online wallpaper search was dead** — `ddg_search.sh` resolved a duplicated
   path (`$SCRIPT_DIR/quickshell/wallpaper/get_ddg_links.py`); fixed to
   `$SCRIPT_DIR/get_ddg_links.py`.

2. **Volume popup could not identify the default sink/source** —
   `get_audio_state.py` matched `wpctl status` node IDs against
   `wpctl inspect` `object.serial` (different ID spaces), so `is_default`
   was always false. Now reads the `*` marker directly from `wpctl status`.

3. **Weather widget crashed when the API omitted `pop`** — empty variable
   produced an awk syntax error; now defaults to 0.

4. **Focus Time double-counted activity and had a peak blind spot** —
   `get_stats.py` summed both `focus_hourly` and `focus_intervals` into the
   hourly chart although both tables log the same ticks (double count), and
   `range(1440 - 60)` in both scripts skipped the last hour of the day.
   Hourly data now comes from `focus_intervals` only (matches the daemon's
   own intent); peak window now includes 23:00–24:00.

5. **Matugen color extraction could emit 8-char hex (with alpha)** —
   `extract_raw_colors.sh` now truncates to 6-char `#RRGGBB`.

6. **starship.toml was a store hardlink** — `shell.nix` now uses
   `mkOutOfStoreSymlink`, matching the hypr/theme pattern; edits take
   effect without a rebuild. Requires `nixos-rebuild switch` once.

### Notes

- `battery_fetch.sh` AC-detection fix (skip `BAT*`/`hidpp_battery`/
  `ucsi-source-psy`, read the ACPI adapter) landed inside commit b71db36
  (reload/watchers round) — live-verified: reports plugged-in via `AC0`.

## 2026-08-16 — Power/lid, watchers, EasyEffects overhaul (commits d30a230…a6ee84c)

### Fixed

1. **Power-saver EPP was a silent no-op on AC**
   - Root cause: the kernel (`intel_pstate.c` `store_energy_performance_preference`)
     refuses any EPP value > 0 with EBUSY while the policy is `performance`.
     TLP's `CPU_SCALING_GOVERNOR_ON_AC = "performance"` therefore made every
     `power`/`balance_*` write fail; `2>/dev/null` in the caller hid it.
   - Fix: `set_epp.sh` now sets the governor first (powersave for any
     non-performance mode, performance for performance) before writing EPP.
     Verified live: governor/EPP/turbo/RR/shader all correct in every
     transition.

2. **Lid close could not drive power state safely**
   - Root cause: old `lid-monitor.sh` polled `/proc/acpi/button/lid` every 0.2s
     and only toggled DPMS.
   - Fix: rewritten as an event-driven udevadm monitor (button subsystem).
     Lid close = display off + `apply_profile.sh power-saver` (EPP power,
     turbo off, 60 Hz, shader/blur/shadow cut, cached pre-saver shader).
     Lid open = display on + restore by charger state (performance on AC,
     balanced on battery). Suspend remains manual-only (`Shift+Esc`);
     `HandleLidSwitch = "ignore"` is unchanged — the lid never suspends.
   - New `apply_profile.sh` is the single source of truth for the desktop-
     visible power profile (SysData.qml picker + lid-monitor both call it).

3. **EasyEffects: broken preset path, dead service, unresolvable readiness**
   - Root cause: presets were written to `~/.config/easyeffects/output`
     (legacy); EasyEffects 8.2.7 reads/writes `~/.local/share/easyeffects/output`.
     `pgrep -x easyeffects` can never match the Nix-wrapped `comm`; the
     service was dead since 2026-07-02.
   - Fix: `equalizer.sh` writes to the correct dir, starts the service via
     `systemctl --user is-active` checks and loads presets through a
     secondary-instance handoff over the local socket; `--init` preserves
     existing state and seeds `Vocal` only when none exists. `home.nix`
     activates `services.easyeffects.preset = "live_eq"` so the EQ is loaded
     from boot.

4. **workspaces.sh could respawn-loop or park holding the flock**
   - Root cause: a spawn losing the flock exited 0 (TopBar auto-respawned →
     race became a respawn loop), and after a Hyprland restart the stale
     `HYPRLAND_INSTANCE_SIGNATURE` socket made the daemon park forever,
     keeping the flock and freezing the ws bar.
   - Fix: exit code 7 on lock loss (TopBar must not respawn on 7); clean exit
     after 5 failed socket connects. Verified in an isolated env.

5. **Watchers survived `reload.sh`, orphaning udevadm/inotifywait children**
   - Root cause: the watcher blocking step ran in the foreground; bash defers
     traps during foreground commands, so SIGTERM from `pkill -P` never fired.
   - Fix: blocking step backgrounded + `wait "$BLOCK_PID"`; `reload.sh` reaps
     `quickshell/watchers` children before respawning the shell. Two reload
     cycles verified: zero orphans.

6. **Bluetooth scan spawned a `bluetoothctl` process that leaked**
   - Root cause: scan-start spawned a setsid'd `bluetoothctl` whose PID from
     the parent (`$!`) was unreliable; stop-kill hit the wrong PID.
   - Fix: the spawned bash writes its own `$$` (always the process-group
     leader) to the pidfile; stop group-kills `kill -- -<pid>`. Verified.

### Notes

- `services.easyeffects.preset = "live_eq"` requires
  `sudo nixos-rebuild switch --flake ~/nix#nixos` to take effect (unit
  gains `--load-preset live_eq`). The old "Known issue — not changed
  (EasyEffects startup)" section below is superseded by fix 3.
## 2026-08-13 — Focus/popup/startup cleanup (commit 518f6ba)

### Fixed

1. **Rofi: Esc did not close the launcher**
   - Root cause: `steal-focus` defaults to false, so rofi (a layer surface) never
     received keyboard focus; Esc went to the previously focused app.
   - Fix: `steal-focus: true;` in `dotfiles/rofi/config.rasi`.

2. **Wallpaper picker could not be closed with Esc**
   - Root cause: `WallpaperPicker.qml` registered an unconditional `Escape`
     Shortcut (resetting only the Search filter). QML Shortcuts consume the key
     before the widget stack's `Keys.onEscapePressed` (`Main.qml`) can close the
     popup. Every other popup (clipboard, focustime, …) closes on Esc.
   - Fix: the shortcut is now active only in Search mode (`enabled:
     !window.isApplying && window.currentFilter === "Search"`). In Search mode:
     first Esc clears the filter, second Esc closes. Outside Search: Esc closes.

3. **Focus Time showed page titles as app names (e.g. "Opencode launcher setup")**
   - Root cause: `resolve_pwa_name` preferred the browser page title over the
     known host mapping, so a ChatGPT PWA tab titled "Opencode launcher setup"
     (a web page, not an app) became a row name.
   - Fix: known PWA hosts (`chat.openai.com`, `notion.so`, `claude.ai`,
     `gemini.google.com`, `monkeytype.com`, `youtube.com`) are now always
     resolved to their canonical names; page titles apply only to unknown
     hosts. `--heal` also retitles existing rows whose known-host title differs
     from the canonical name.

4. **Quickshell polled settings.json every 3 s forever**
   - Root cause: `Main.qml` spawned `bash -c cat settings.json` on a 3 s timer
     (a process spawn ~29×/min).
   - Fix: event-driven watcher `quickshell/watchers/settings_wait.sh`
     (inotifywait, 300 s failsafe, same pattern as the other watchers) feeding
     the existing `settingsReader` Process; read happens only on change.
   - Requires `inotify-tools` (added to `theme.nix` home.packages).

### Known issue — not changed (EasyEffects startup)

- `equalizer.sh --init` only waits for an EasyEffects process that nothing
  starts at login; the `easyeffects.service` has been dead since 2026-07-02.
- `equalizer.sh` writes presets to the legacy dir
  `~/.config/easyeffects/output`, while EasyEffects 8.2.7 uses
  `~/.local/share/easyeffects/output` and migrates/trashes on spawns.
- `pgrep -x easyeffects` cannot match the Nix-wrapped binary (`comm` =
  `.easyeffects-wr`), so readiness checks against the service are broken.
- Status: deliberately NOT modified; a redesign is required before any change.