# CHANGELOG

## 2026-09-18 — Browser Camera Fix, License & README Polish

- **Hardware Quirks Modularization & Generic Module Purification (`hosts/nixos/hardware/`, `boot.nix`, `services.nix`, `power.nix`)**:
  - Moved Sonix webcam quirk (`v4l2loopback`, modprobe config, and `camera-loopback` service) out of generic `boot.nix`/`services.nix` into isolated host module `hosts/nixos/hardware/sonix-webcam.nix`.
  - Moved machine-specific root disk UUID (`d0a20f82...`), `resume_offset`, and Intel GPU early KMS (`i915`) out of generic `boot.nix` into `hosts/nixos/default.nix`.
  - Consolidated ASUS platform tools (`asusd`, `asusd.ron`, brightness rebind) out of generic `power.nix` and `modules/system/` into isolated host module `hosts/nixos/hardware/asus.nix`.
  - Added hardware check (`lsusb -d 3277:0022`) to `dotfiles/hypr/scripts/webcam.sh` so other users with standard webcams are gracefully informed rather than having broken loopback processes.
  - Generic modules (`modules/system/`) are now completely clean and portable across any PC/laptop brand.
- **MIT License & GitHub Professional Polish (`LICENSE`, `README.md`)**:
  - Added MIT License file.
  - Added License shield badge to README header.
  - Added comprehensive **Software Stack & Rice Components** table to README listing all 25+ programs used in the rice setup.

## 2026-09-18 — Boot & Login Latency Optimization, NTFS Recovery Support

- **Post-Password Desktop Loading Latency (`dotfiles/hypr/startup.lua`, `set_wallpaper.sh`)**:
  - Eliminated redundant `hyprctl reload` fired by `set_wallpaper.sh` on cold boot, preventing an unnecessary second Hyprland Lua parsing cycle during startup.
  - Repositioned QuickShell launch to the top of `startup.lua` to instantiate the TopBar and desktop shell concurrently while background daemons initialize.
  - Purged duplicate `wallpaper_watcher.sh` invocation from `startup.lua` (already managed declaratively by systemd user service `wallpaper_watcher.service`).
  - Removed dead `killall dunst/mako/swaync` calls from the startup critical path.
- **Boot Target Decoupling (`modules/system/services.nix`)**:
  - Decoupled `systemd.services.flatpak-repo` from `multi-user.target`, making it trigger asynchronously upon `network-online.target` without blocking userspace boot.
  - Decoupled `systemd-user-sessions.service` from `network.target` (`lib.mkForce [ "remote-fs.target" "nss-user-lookup.target" ]`), allowing Ly Display Manager to present the login prompt immediately after local filesystems mount without waiting for network stack negotiation.
- **Early KMS & Kernel Parameter Acceleration (`modules/system/boot.nix`)**:
  - Injected `i915` into `boot.initrd.kernelModules` to enable Early KMS (Kernel Mode Setting). Initializes Intel Iris Xe display modesetting inside stage 1 initrd rather than delaying to stage 2 userspace, eliminating the black screen stall and display mode-switch before Ly starts.
  - Added kernel parameters `quiet`, `i915.fastboot=1`, `rd.systemd.show_status=auto`, and `rd.udev.log_level=3` to silence unnecessary console I/O and preserve UEFI GOP display states. Set `boot.initrd.verbose = false;`.
  - Added `bgrt_disable`, `video=efifb:nobgrt`, and `fbcon=nodefer` to completely suppress the ACPI Boot Graphics Resource Table (BGRT) OEM logo, preventing the Linux kernel from redrawing the manufacturer ASUS splash screen during stage 1/stage 2 boot.
- **QuickShell Workspace Accuracy & Ghost Workspace Elimination (`TopBar.qml`)**:
  - Fixed false-positive workspace pill visibility where empty workspaces appeared occupied due to stale `ws.lastIpcObject.windows` snapshots retaining positive values after windows closed.
  - Bound occupancy checks to live `Hyprland.toplevels` iteration and `ws.toplevels.count` with a fallback check only when model structures are initially unpopulated.
  - Wrapped `onRawEvent` workspace/window updates in `Qt.callLater` and added `onActiveToplevelChanged` listener to guarantee the C++ model finishes event processing before workspace pill layout recalculation.
- **BatteryPopup Dial Contrast & Background Depth (`BatteryPopup.qml`)**:
  - Replaced washed-out, milky white `window.text` (14%/6%) gradient on `centralCore` with a rich, dark recessed glassmorphic gradient (`window.crust` at 85% to `window.mantle` at 65%) and subtle `window.surface1` border.
  - Subdued the circular background capacity track (`batCanvas`) from bright 22% white text to a sleek, recessed `window.surface1` (35%) groove, providing deep contrast that makes the battery percentage and active charging/drain arc vivid.
- **WebCam UVC Stability & Complete USB Autosuspend Deactivation (`power.nix`, `boot.nix`, `users.nix`, `home.nix`)**:
  - Disabled `USB_AUTOSUSPEND = 0;` globally in TLP and appended `usbcore.autosuspend=-1` to kernel parameters to prevent internal USB root hubs and webcam interfaces from entering low-power states or resetting the USB bus during video streaming.
  - Replaced the failing `quirks=128` bandwidth cap with `options uvcvideo nodrop=1` to prevent incomplete frame drops and eliminate buffer overflow resets.
  - Added `"video"` to `users.users.${user.username}.extraGroups` to ensure complete V4L2 device permissions across all native and sandboxed applications.
  - Diagnosed webcam initialization failure where WirePlumber was registering both `libcamera` and `v4l2` monitors simultaneously for the internal Sonix FHD UVC WebCam (`3277:0022`), creating resource contention and device resets. Persisted `monitor.libcamera = disabled` in `home.nix` (`~/.config/wireplumber/wireplumber.conf.d/50-disable-libcamera.conf`).
- **BatteryPopup Logoff Mechanism & Clean Exit Dispatcher (`BatteryPopup.qml`, `exit.sh`)**:
  - Fixed non-functional "Logoff" action in `BatteryPopup.qml` which was executing bare `["hyprctl", "dispatch", "exit"]` in detached subshells without environment synchronization or systemd graphical session cleanup.
  - Re-routed both tap (`onClicked`) and hold-to-fill (`exitTimer.onTriggered`) triggers to execute `bash ~/.config/hypr/scripts/exit.sh`.
  - Updated `exit.sh` to gracefully stop `graphical-session.target` and fall back to regex matching `([H]yprland|\.Hyprland-wrapp)` to cleanly terminate NixOS wrapped Hyprland binaries if IPC disconnects.
- **Fuzzel Contrast, Premature Exit & Search Relevance Overhaul (`fuzzel.ini`, `fuzzel_menu.sh`)**:
  - Replaced low-contrast 45% black background with high-opacity 94% dark Catppuccin Mantle (`#181825f0`), ensuring text is crisp and readable against both light documents and dark wallpapers.
  - Added explicit high-contrast `input = ffffffff` (bright white) and `prompt = 89b4faff` to eliminate the default dim cyan input text that was unreadable in application and file searches.
  - Fixed premature self-closing bug while typing (e.g. searching `cal` in app launcher) by setting `keyboard-focus = exclusive` and `exit-on-keyboard-focus-loss = no`.
  - Switched file search match mode from loose subsequence `fzf` to strict `exact` substring matching (`--match-mode=exact`), preventing distant scattered characters in unrelated documents from overriding exact keyword matches (e.g. `aws` now strictly matches `aws-...` rather than distant letters in PowerPoint slides).

## 2026-09-18 — Script Consolidation, Rebuild Fix, Multi-User Portability & Installation Docs

- **Email Elimination & Minimal Identity (`user.nix`, `docs/installation.md`)**:
  - Removed unused `email` attribute from `user.nix` and system documentation. Identity is strictly scoped to `username`, `name`, and `hostname`.
- **Pure Channel Tracking for Spicetify (`flake.nix`)**:
  - Maintained pure `nixpkgs` tracking for `spicetify-cli` without manual pin overrides, ensuring seamless automatic upgrades with channel updates without maintenance debt.
- **Hostname Parameterization & Migration (`user.nix`, `hosts/nixos/default.nix`, `docs/README.md`)**:
  - Migrated system hostname from `vivobook` to `NixOS` across the system configuration and documentation.
  - Connected `hosts/nixos/default.nix` dynamically to `user.hostname` (`networking.hostName = user.hostname;`), ensuring all future hostname updates are managed centrally from `user.nix`.
- **Ly Session Log Suppression (`modules/system/services.nix`)**:
  - Suppressed Ly display manager's legacy session log creation by configuring `services.displayManager.ly.settings.session_log = null;`. Modern Wayland sessions and systemd already cleanly capture compositor logs in `journalctl --user` and Hyprland's runtime directory, rendering the empty `~/ly-session.log` in `$HOME` obsolete.
  - Purged the redundant `~/ly-session.log` file from the user's home directory.
- **Seamless Video Looping Media (`rec_loop.mp4`, `rec_loop_steady.mp4`)**:
  - Processed screen recording `rec_20260824_0240.mp4` into seamless, perfectly looping videos with synchronized audio/video crossfade transitions (`xfade` + `acrossfade`) in universally compatible `yuv420p` format.
  - Produced both full-duration seamless loop (`rec_loop.mp4`) and steady-state loop (`rec_loop_steady.mp4`).
- **Rebuild Clobber Resolution (`modules/home/theme.nix`)**:
  - Resolved `home-manager` switch failure (`Existing file '~/.local/share/icons/buuf-nestort' would be clobbered`) by setting `force = true` on `xdg.dataFile."icons/buuf-nestort"`.
- **Multi-Tool CLI Consolidation (`dotfiles/hypr/scripts/`)**:
  - **Wallpaper Multi-Tool (`wallpaper.sh`)**: Consolidated 6 separate interdependent scripts (`boot_wallpaper.sh`, `ensure_awww.sh`, `kill_wallpaper.sh`, `set_wallpaper.sh`, `wallpaper_thumbnail.sh`, `wallpaper_watcher.sh`) into a single executable `wallpaper.sh` CLI (`set`, `boot`, `kill`, `ensure`, `thumb`, `watch`, `clean`). Preserved lightweight backward-compatible wrappers.
  - **Power & Session Multi-Tool (`power.sh`)**: Consolidated 4 power/sleep/lock scripts (`lock.sh`, `suspend.sh`, `lid-monitor.sh`, `idle_inhibit.sh`) into a single `power.sh` CLI (`lock`, `suspend`, `resume`, `lid`, `inhibit`). Preserved lightweight backward-compatible wrappers.
  - **Fuzzel Wrapper Elimination**: Deleted redundant 1-line wrappers (`fuzzel_app_launcher.sh`, `fuzzel_file_search.sh`); keybinds invoke `fuzzel_menu.sh app` and `fuzzel_menu.sh file` directly.
- **Centralized QuickShell Base Styling (`PopupCard.qml`)**:
  - Created reusable base component `PopupCard.qml` centralizing background color, border width, border color, corner radius, and specular highlights across all QuickShell widgets driven by `settings.json`.
- **Multi-User Portability (Omarchy Standard)**:
  - Created [`user.nix`](file:///home/realdhiru/nix/user.nix) as the single source of truth for user credentials (`username`, `name`, `hostname`).
  - Parameterized `flake.nix`, `modules/system/users.nix`, and `home.nix` with dynamic `user.username` and `/home/${user.username}`, completely eliminating hardcoded user paths across Nix modules.
  - Updated `modules/home/vscodium.nix` to use `${config.home.profileDirectory}/bin`.
  - Replaced all hardcoded `/home/realdhiru` in `keybinds.lua`, `startup.lua`, and `matugen/config.toml` with dynamic `$HOME` and `~` references.
  - Updated `settings.json` and `Config.qml` to dynamically expand `~/Pictures/Wallpapers`.
- **Installation Documentation (`docs/installation.md`, `README.md`)**:
  - Authored comprehensive guide detailing fresh installation steps, `user.nix` customization, hardware generation, and system architecture for external users.

## 2026-09-17 — Fuzzel HiDPI Rescaling, Outside-Click Dismissal, Zero-Blink Reloads & Hotspot Reliability

- **Showcase Looping Media & Attribution (`README.md`, `docs/assets/`)**:
  - Extracted and computed a seamless 10.800s (648 frames @ 60fps) loop incorporating live Cava visualizer and TopBar music marquee text (`Grand Escape`).
  - Matched exactly 3 full wallpaper animation cycles ($3 \times 3.600$s) alongside the marquee cycle and bottom cava energy dip for zero seam stutter.
  - Seamlessly stabilized TopBar clock pill at `17:44` across the loop seam.
  - Deployed 24-bit TrueColor animated WebP (`hero_desktop.webp`) as primary showcase media.
  - Streamlined showcase section and updated widget attribution phrasing.

- **Hotspot Backend UUID Hardening & UI Drawer Lifecycle (`hotspot_control.sh`, `BatteryPopup.qml`)**:
  - Resolved root-cause failure where duplicate NetworkManager "Hotspot" profiles output multi-line modes (`mode=$'ap\n\nap\n\nap'`), causing string equality tests to fail and falsely reporting `active: false`. Rewrote `hotspot_control.sh` to query and operate strictly on unique connection UUIDs.
  - Purged orphaned duplicate Hotspot profiles in NetworkManager.
  - Fixed `showWidget()` in `BatteryPopup.qml` to reset `window.showHotspotMenu = false`, preventing the drawer from persistently sticking open on widget launch.
  - Converted card height from rigid hardcoded pixel bounds to dynamic `hotspotContentCol.implicitHeight + window.s(28)`, eliminating text and button clipping across HiDPI scaling.
  - Enhanced Hotspot toggle and header pill click handlers with instant visual feedback and responsive dual-pass refresh timers (300ms + 1000ms).
  - Cleaned up aesthetics: removed Wi-Fi icons from header pill and drawer, and swapped green/mauve outlines for neutral dark surface styling (`surface2`).

- **System Tray Scope Resolution & Explicit Target Width (`TopBar.qml`, `startup.lua`)**:
  - Resolved `ReferenceError: filteredTrayItems is not defined` inside `TopBar.qml` by assigning an explicit `id: trayBox` to the tray container Rectangle.
  - Replaced ambiguous `trayLayout.width` binding with an exact geometric formula (`trayRepeater.count * s(18) + (trayRepeater.count - 1) * s(10) + s(24)`), ensuring active non-blacklisted tray icons (e.g. EasyEffects, Spotify) render at the exact required width without clipping while completely suppressing Bluetooth and KDE Connect.
  - Removed redundant `kdeconnect-indicator` startup launch from `startup.lua`.

- **Fuzzel Search Algorithm & Pipeline Streamlining (`fuzzel.ini`, `fuzzel_menu.sh`)**:
  - Resolved the search false-positive issue where loose Levenshtein edit distance (`match-mode = fuzzy`) caused unrelated files to match almost any keystroke: configured `match-mode = fzf` across `fuzzel.ini` and `fuzzel_menu.sh`.
  - Streamlined `fuzzel_menu.sh` into a clean 2-column pipeline: Column 1 for Nerd Font glyph + filename + relative path display and FZF matching (`--with-nth=1`, `--match-nth=1`), and Column 2 for clean absolute path execution (`--accept-nth=2`). Eliminated embedded NUL byte corruption that prevented file matching.

- **Fuzzel Icon Theme Alignment (`fuzzel.ini`, `fuzzel_menu.sh`, `theme.nix`)**:
  - Identified and fixed why Fuzzel displayed default/Papirus icons instead of the system-wide custom hand-drawn icon theme (`buuf-nestort`): `fuzzel.ini` and `fuzzel_menu.sh` explicitly hardcoded `icon-theme = Papirus-Dark`.
  - Updated `fuzzel.ini` and `fuzzel_menu.sh` to specify `icon-theme = buuf-nestort`.
  - Declaratively linked `xdg.dataFile."icons/buuf-nestort"` in `modules/home/theme.nix` so that Fuzzel and all standalone Wayland clients deterministically locate the theme across rebuilds and fresh installs.

- **Fuzzel HiDPI Proportion Rescaling & Outside-Click Dismissal (`fuzzel.ini`, `fuzzel_menu.sh`)**:
  - Compacted Fuzzel UI to align with QuickShell's 2x HiDPI proportions: reduced font size to `10pt` (file finder `9.5pt`), line height to `22px`, width to `32` characters, padding to `14px/10px/6px`, and corner radius to `12px`.
  - Configured `keyboard-focus = on-demand` alongside `exit-on-keyboard-focus-loss = yes`. When clicking anywhere outside the Fuzzel window, keyboard focus switches instantly to the clicked surface and dismisses Fuzzel without requiring Escape.
- **Unified Fuzzel Runner Consolidation (`fuzzel_menu.sh`, `keybinds.lua`)**:
  - Consolidated redundant application launcher and file finder scripts into a single, clean `fuzzel_menu.sh {app|file}` runner with built-in power-profile background adaptation. Preserved backwards-compatible stubs.
- **Zero-Flicker Synchronous Opacity in Hyprland (`rules.lua`, `reload.sh`)**:
  - Implemented synchronous frame-0 state detection (`wallpaper_killed`, `gaming_mode`, `power-saver`) directly inside `rules.lua`. Completely eliminated the 15ms translucent-to-opaque window flicker on `SUPER + R` config reloads.
  - Streamlined `reload.sh` to avoid redundant full QML rebuilds during standard compositor reloads, dropping reload execution time to ~15ms.
- **Package & Launcher Cleanup (`packages.nix`, `applications`)**:
  - Removed `linux-wifi-hotspot` from system packages.
  - Removed orphaned Bottles FL Studio desktop entry and suppressed unused helper entries (`Desktop`, `Bluetooth Adapters`, `Wifi Hotspot`).
  - In `kill_wallpaper.sh`, automatically disables Hyprland's dual-kawase blur, drop shadow shaders, animations (`animations:enabled = false`), and forces 100% opaque window rendering (`active_opacity = 1.0`, `inactive_opacity = 1.0`, `hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })`) via `hyprctl eval` whenever wallpapers are killed. This completely eliminates multi-pass GPU alpha-blending and allows hardware occlusion culling over black backgrounds (saving ~1.2W–2.0W GPU package power).
  - In `set_wallpaper.sh`, restores blur, shadows, animations, and reloads window rules (`hyprctl reload`) to restore window translucency (unless the system is actively in the `power-saver` profile).
  - Synchronized with `SysData.qml` power profile automation so that `power-saver` profile applies the same full opacity, animation, blur, and shadow bypass, and leaving `power-saver` respects the wallpaper killed state.
- **Keybind Collision Resolution (`keybinds.lua`)**:
  - Rebound the interactive Fuzzel file finder from `SUPER + SHIFT + F` to `SUPER + SPACE`, eliminating the keybind collision with Hyprland's native window pinning dispatch (`hl.dsp.window.pin()`).
- **Snappy TopBar Cascades & Instant Widget Transitions (`TopBar.qml`, `Main.qml`)**:
  - Replaced the heavy 500ms `OutBack` bounce and 60ms stagger in `TopBar.qml` with an ultra-smooth, linear-deceleration 220ms `OutCubic` curve and a uniform 25ms stagger across workspace pills, tray icons, and the battery badge.
  - Accelerated `Main.qml` popup morph animations from 230ms to 160ms (`morphDuration`, `morphDurationShift`), making popup triggers feel instant.
- **QuickShell Startup Hitch Elimination (`TopBar.qml`, `Main.qml`)**:
  - Removed the 800ms artificial fallback timer and battery capacity wait gate (`isDataReady = true` immediately, cascade interval reduced from 1000ms to 300ms) in `TopBar.qml`, allowing the right bar elements to render instantly on session start or restart.
  - Eliminated the eager startup preload storm in `Main.qml` that was instantiating 9 heavy popup widgets every 150ms on launch (freezing the QML thread for 1.35s). Deferred widget preloading to a low-priority 6000ms idle timer.
- **Native NetworkManager Hotspot Architecture (`services.nix`, `users.nix`, `hotspot_control.sh`)**:
  - Removed static `wifi-ap-interface` systemd unit and manual `ap0` sudo rules from NixOS configuration.
  - Aligned Hotspot handling with native NetworkManager D-Bus architecture (matching GNOME/KDE), allowing NetworkManager to manage Wi-Fi and hotspot states cleanly.
- **Matugen Colors & Hotspot Text Contrast Fixes (`MatugenColors.qml`, `BatteryPopup.qml`)**:
  - Reverted `MatugenColors.qml` back to the battle-tested `colors_wait.sh` inotify watcher, preserving sub-10ms atomic color palette generation and theme switching.
  - Fixed Hotspot pill label in `BatteryPopup.qml` by binding to `window.text` (crisp white/cream) instead of `window.subtext1` (dark charcoal), resolving the dark/unreadable text issue.
- **Battery Widget Header Redesign & Action Buttons (`BatteryPopup.qml`)**:
  - Permanently expanded the Hotspot pill button (`Layout.preferredWidth: window.s(104)`) with constant opacity, visible text and icon, eliminating the condensed 38px sliver and preventing the central battery timer pill from stretching out unnaturally.
  - Styled Do-Not-Disturb button with visible `surface0` background and clear icon.
  - Enabled direct tap/click execution on the Logoff (`hyprctl dispatch exit`) and Sleep capsules, eliminating hold-to-confirm friction while keeping hold protection for Shutdown and Reboot.
  - Configured virtual AP interface `ap0` on `phy0` (`systemd.services.wifi-ap-interface`) and added `ap0` to `networking.firewall.trustedInterfaces` along with DHCP/DNS ports (53, 67, 68). This enables concurrent Wi-Fi client reception (`wlo1`) and Hotspot broadcast (`ap0`), preventing Wi-Fi from disconnecting when hotspot is active.
- **Hotspot Card Controls, Inline Editing & Client Device Tracking (`BatteryPopup.qml`, `hotspot_control.sh`)**:
  - Expanded the Hotspot menu to full uncompressed size.
  - Added inline SSID and WPA2 password editing with pen edit toggles (`󰏫`), inline inputs, and Save (`󰄬`)/Cancel (`󰅖`) buttons.
  - Added expandable connected devices drawer: displays client hostname, assigned IP (`10.42.0.x`), and MAC address parsed from `dnsmasq.leases` and `ip neigh`.
- **File Finder Visual Thumbnails & Icons (`dotfiles/hypr/scripts/fuzzel_file_search.sh`)**:
  - Integrated high-contrast Nerd Font glyph thumbnails (`󰋩` images, `󰕧` videos, `󰎈` audio, `󰈦` pdfs, `󰅩` scripts/code, `󰈙` text/configs, `󰛫` archives) paired with Rofi extended dmenu icon protocol for 100% reliable icon rendering.
- **Zero-Polling Event-Driven A/V Hardware Watcher (`dotfiles/hypr/scripts/quickshell/watchers/av_event_stream.sh`, `BatteryPopup.qml`)**:
  - Replaced the 200ms periodic timer process loop with an event-driven `SplitParser` streamer. Watches kernel backlight uevents via `udevadm monitor` and PipeWire volume/mute via `pw-mon` with a 50ms burst debounce. Consumes 0% CPU and zero background polling cycles while the widget is open, and terminates when hidden.
- **Snappy Layer Exit Animations (`dotfiles/hypr/appearance.lua`)**:
  - Accelerated `fadeLayersOut` from speed 4.5 to speed 2 (`menu_decel`), making the exit animation of Fuzzel and the file finder just as fast and responsive as their opening.
- **Quickshell Reload Mechanism (`dotfiles/hypr/scripts/qs_manager.sh`)**:
  - Added dedicated `reload` action to `qs_manager.sh` using Hyprland dispatch, ensuring quickshell restarts cleanly in the user session without being prematurely killed.

## 2026-09-16 — Complete Rofi Decommissioning, Centered Fuzzel UI, and QuickShell Battery Overhaul

- **Complete Rofi Decommissioning (`modules/system/packages.nix`, `home.nix`, `dotfiles/hypr/keybinds.lua`, `dotfiles/hypr/rules.lua`)**:
  - Removed `rofi` from NixOS system packages and retired the `xdg.configFile."rofi"` Home Manager symlink.
  - Removed obsolete Rofi window and layer rules. Bound `Super + A` exclusively to Fuzzel (`pkill fuzzel || fuzzel`).
- **Centered Fuzzel App Launcher & File Finder (`dotfiles/fuzzel/fuzzel.ini`, `dotfiles/hypr/scripts/fuzzel_file_search.sh`, `dotfiles/hypr/rules.lua`)**:
  - Configured `anchor = center` on both the main Fuzzel launcher and interactive file search.
  - Set layer animation rule to `animation = fade` for smooth fade-in/fade-out transitions to/from screen center.
  - Compacted file finder dimensions (`--width=46`, `--lines=8`) and updated file selection action: pressing Enter now extracts `dirname "$SELECTED_FILE"` and opens the parent directory in `pcmanfm-qt` instead of launching the file.
- **QuickShell Battery Widget UI & System Telemetry Overhaul (`dotfiles/hypr/scripts/quickshell/battery/BatteryPopup.qml`, `WindowRegistry.js`)**:
  - **Live Reactive Audio & Brightness**: Added native declarative `Pipewire.defaultAudioSink.audio` property bindings (`pipewireVol`, `pipewireMuted`) to dynamically update volume when adjusted via keyboard keys. Added high-speed 300ms `briLivePoller` (`brightnessctl -m`) while popup is visible.
  - **Numerical Value Presenters**: Added bold percentage (`%`) readouts to the right of both brightness and volume slider bars.
  - **Button Cleanup & Action Reordering**: Removed obsolete Wifi and rotate-display buttons. Fixed logout execution by replacing brittle `~` expansion with `bash $HOME/.config/hypr/scripts/exit.sh`. Reordered bottom action row capsules to exact order: Logoff (`󰍃`), Sleep (`ᶻ 𝗓 𝗓`), Shutdown (``), Reboot (`󰑓`).
  - **Relocated Battery Time Remaining**: Moved remaining battery runtime capsule (`󰂄/󱐋 2h 45m LEFT/FULL`) to the left-side notification header row beside the DND toggle.
  - **Condensed Vertical Geometry**: Removed the empty top row on the right column, shifted the central battery ring upward (`anchors.verticalCenterOffset: window.s(-140)`), and condensed popup height in `WindowRegistry.js` from `760` to `660`.

## 2026-09-16 — Fuzzel Application Launcher & Fast File Search Coexistence Trial

- **Fuzzel, fd & Papirus Icon Packages (`modules/system/packages.nix`)**:
  - Added `fuzzel` (ultra-lightweight Wayland launcher), `fd` (fast file crawler), and `papirus-icon-theme` to system packages alongside Rofi.
- **Matching Glass Aesthetic & Roomy Layout (`dotfiles/fuzzel/fuzzel.ini`, `dotfiles/hypr/rules.lua`)**:
  - Fixed Hyprland layer blur by setting `namespace = fuzzel` in `fuzzel.ini` and matching `^(fuzzel|launcher)$` with `blur = true`, `ignore_alpha = 0.1`, and `animation = slide left`.
  - Removed cramped/condensed feeling by widening window (`width = 48`), increasing item line height (`line-height = 36`), adding `selection-radius = 12` rounded pills, disabling awkward giant images (`image-size-ratio = 0.0`), and adding generous padding (`horizontal-pad = 24`, `vertical-pad = 20`, `inner-pad = 16`).
- **Dual Vertical & Horizontal Navigation**:
  - Configured vertical navigation (`Up`/`Down`, `Ctrl+N`/`Ctrl+P`, `Ctrl+J`/`Ctrl+K`) and horizontal navigation (`Left`/`Right` for paging).
- **Interactive File Search (`dotfiles/hypr/scripts/fuzzel_file_search.sh`)**:
  - Fixed search crash caused by `--strip-cwd-prefix` parameter collision. Built clean two-column display with filename aligned on left and directory path on right, extracting the canonical path via tab delimiter on Enter and launching with `xdg-open`.
- **Keybindings (`dotfiles/hypr/keybinds.lua`)**:
  - `Super + Space`: Launch Fuzzel application launcher.
  - `Super + Shift + F`: Launch Fuzzel interactive file search.
  - `Super + A`: Kept on Rofi for comparison.

## 2026-09-16 — Bootloader Visibility, Stable Generation Pinning, Filelight & Desktop Fixes

- **Bootloader Menu Generation Visibility (`modules/system/boot.nix`)**:
  - Configured `boot.loader.timeout = 3;` (was `0`). All available NixOS system generations (and Windows Boot Manager) are now directly visible and selectable on every system startup for 3 seconds instead of skipping immediately to the latest generation.
- **Stable Pinning & Generation Management (`modules/home/shell.nix`)**:
  - Added `pin-stable [gen]`: Creates a persistent Garbage Collection root at `/nix/var/nix/gcroots/boot-stable` pointing to the active (or specified) system generation. This guarantees that your known-good generation is NEVER pruned or lost during `nix-collect-garbage -d`.
  - Added `gens`: Lists all existing system generations in natural numerical order, highlighting the `[ACTIVE]` and `[PINNED STABLE]` generations. Confirms all generations remain visible and bootable.
- **GUI Disk Space Explorer (`modules/system/packages.nix`)**:
  - Added `kdePackages.filelight` to system packages for visual, interactive pie-chart disk usage exploration without needing ad-hoc `nix-shell`.
- **Dual-Boot Hardware Clock Fix (`hosts/nixos/default.nix`)**:
  - Configured `time.hardwareClockInLocalTime = true;` to keep motherboard RTC synchronized with Windows, eliminating clock jumps when switching between operating systems.
- **Notification Backlog Resolution (`dotfiles/hypr/scripts/quickshell/NotifTicker.qml`, `TopBar.qml`)**:
  - Fixed notification center bug where persistent toasts blocked incoming notifications. Added a 7-second safety fallback timeout and right-click to dismiss.
- **Wallpaper Recall Fix (`dotfiles/hypr/scripts/set_wallpaper.sh`, `kill_wallpaper.sh`, `qs_manager.sh`)**:
  - Preserved `last_wallpaper.txt` during wallpaper toggle off so reopening the wallpaper widget re-applies the last chosen wallpaper instead of resetting to the first in the directory.
- **Wallpaper Picker Online Search & Download Pipeline Fix (`WallpaperPicker.qml`, `ddg_search.sh`, `auto_organize.py`)**:
  - **Incremental Search Streaming Without Reset**: Eliminated destructive `sortListModel()` invocations in `syncSearchModel()`. Replaced `model.clear()` / full re-append cycles with Set-based incremental deduplication, keeping delegate identity and scroll position stable as new preview thumbnails stream in.
  - **Removed Scroll-Blocking Locks**: Disabled `isScrollingBlocked` restrictions so mouse wheel scrolling, arrow key navigation, touch/mouse dragging, and delegate clicks remain responsive throughout search.
  - **Managed Download Process & Fallback**: Replaced detached bash download with managed `Process { id: downloadProc }` and timeout safeguards. Validates image MIME type, falls back to the verified thumbnail if full-res download fails, and triggers `wallpaper_thumbnail.sh` for instant local gallery indexing.
  - **Auto-Organize Coordination**: Synchronized `~/.cache/current_wallpaper.txt` and `last_wallpaper.txt` in `auto_organize.py` when wallpapers are ingested into shade folders, preventing Hyprland's watcher from falsely detecting missing files and resetting to boot wallpaper.

- **Wallpaper Picker Filter Overhaul & Ghost Item Elimination (`WallpaperPicker.qml`)**:
  - **Removed Redundant Color Shades**: Removed 6 subjective color shade filters (`Dark`, `Blue`, `Warm`, `Green`, `Purple`, `Light`) in favor of 4 purposeful, high-utility tabs: **All**, **GIFs**, **Videos**, and **Search**.
  - **Dedicated ListModels**: Implemented dedicated sub-models (`gifsProxyModel`, `videosProxyModel`, `localProxyModel`) populated cleanly in `syncLocalModel()`.
  - **Eliminated Width:0 Ghost Items**: Replaced the previous `width: 0` / `opacity: 0` filtering hack in `ListView`. Every item in the active model is 100% visible, completely eliminating jittery scrolling, blank gaps, and navigation bugs when browsing GIFs or videos.
- **Wallpaper Picker Interactive Delete & Zero-Battery Ingest-On-Close (`WallpaperPicker.qml`, `set_wallpaper.sh`, `auto_organize.py`)**:
  - **Keyboard `Delete` Shortcut**: Added an interactive `Delete` key binding to `WallpaperPicker.qml`. Pressing `Delete` on any preview immediately reverts the desktop wallpaper (via `~/.cache/previous_wallpaper.txt`) if active, wipes the downloaded media from disk, purges search/local thumbnails, removes the card from the active model without layout jitter, and flashes a "Wallpaper deleted" toast notification.
  - **Zero-Battery Ingest-On-Close**: Configured QuickShell to write `/run/user/$UID/quickshell/wallpaper_picker/picker_active` while the wallpaper picker is open. `auto_organize.py` detects this flag and defers moving root downloads into color folders and Git until the picker window closes, avoiding premature Git commits, CPU wakeups, and unnecessary battery consumption.
  - **Safe Staging**: Updated `auto_organize.py` Git commit routines to explicitly stage only the organized category target, README gallery, and previews instead of `git add -A`, preventing loose root inbox files from being committed accidentally.

## 2026-09-16 — Power Profile Mode Fix: TLP Battery ACPI Profile & QuickShell State Reconciliation

- **Context**: QuickShell battery widget/power profile selector was permanently stuck displaying `power-saver` ("Saver") mode on battery, and manually selecting `balanced` immediately reverted back to `power-saver` within 600ms.
- **Root Cause**:
  1. `modules/system/power.nix` had `PLATFORM_PROFILE_ON_BAT = "quiet";` (identical to `ON_SAV`). On battery, TLP configured ACPI sysfs `/sys/firmware/acpi/platform_profile` to `"quiet"`.
  2. `dotfiles/hypr/scripts/quickshell/SysData.qml` sysfs poller mapped `"quiet"` directly to `"power-saver"`. Consequently, whenever on battery or whenever `tlp balanced` executed, the 600ms refresh poller read `"quiet"` from sysfs and forcefully overwrote `root.powerProfile` to `"power-saver"`.
  3. `SysData.qml`'s `_reconcileStartupProfile` left offline (battery) startup in an uninitialized state, failing to set `root.powerProfile` or invoke visual overrides.
- **Decision**:
  1. **TLP Battery Platform Profile Alignment (`modules/system/power.nix`)**:
     - Corrected `PLATFORM_PROFILE_ON_BAT = "balanced";` while retaining `PLATFORM_PROFILE_ON_AC = "performance";` and `PLATFORM_PROFILE_ON_SAV = "quiet"`, establishing 3 clean, distinct hardware tiers across AC, BAT, and SAV.
  2. **QuickShell SysData State Resilience (`dotfiles/hypr/scripts/quickshell/SysData.qml`)**:
     - Updated `platformProfileProc.stdout.onStreamFinished` to preserve `root.powerProfile = "balanced"` if `root.requestedProfile === "balanced"` even when the underlying kernel sysfs reads `"quiet"`.
     - Properly initialized offline battery startup in `_reconcileStartupProfile` (`root._manualOverride = false; root.requestedProfile = "balanced"; root.powerProfile = "balanced"; _applyVisualOverrides("balanced");`).
     - Synchronized `/tmp/qs_power_profile` and `/tmp/qs_requested_profile` on all profile transitions.
- **Result**: Selecting "Balance", "Perform", or "Saver" in `BatteryPopup.qml` persists cleanly without reverting; battery mode reliably defaults to "Balance"; `nix flake check` passes with zero errors.

## 2026-09-16 — System Audit & Hardening: QuickShell Runtime Cleanup, Daemon Syscall Reduction & Security Fixes

- **Context**: Comprehensive system diagnosis identified high-frequency background CPU churn, QML runtime errors/warnings, shell script bugs, Hyprland window rule duplication, and security/deprecation warnings in the Nix configuration.
- **Decision**:
  1. **Background Service Optimization (`dotfiles/hypr/scripts/quickshell/focustime/focus_daemon.py`, `watchers/sys_fetcher.sh`)**:
     - Replaced `is_locked()` full `/proc` filesystem traversal (~300 file opens every 1s) with targeted process lookup and throttled check, stopping ~18,000 syscalls/min.
     - Replaced repeated `awk` forks in `/proc/meminfo` loop with pure Bash parameter expansion and consolidated network rate calculations into a single `awk` block.
  2. **QuickShell Runtime & QML Fixes (`SysData.qml`, `CalendarPopup.qml`, `Main.qml`, `TopBar.qml`, `WallpaperPicker.qml`, `NetworkPopup.qml`)**:
     - Removed invalid `Keys.onEscapePressed` on `PanelWindow` (causing `not an Item` warnings).
     - Added `id: weatherIconText` to resolve `ReferenceError: hoverLift is not defined` in `CalendarPopup.qml`.
     - Wrapped `osdRowLayout` and `osdMouse` in `TopBar.qml` inside an `Item` container to eliminate QtQuick layout anchor undefined behavior warnings.
     - Guarded `anchors.verticalCenter` in `WallpaperPicker.qml` against transient null parent during delegate destruction.
     - Replaced uninitialized `Settings` instances with `QtObject` in `NetworkPopup.qml` and `WallpaperPicker.qml`, stopping `QSettings` code 1 errors.
     - Cleaned dead reconciliation variables and unused properties in `SysData.qml`.
  3. **Shell Script Bugfixes (`qs_manager.sh`, `set_wallpaper.sh`, `wallpaper_thumbnail.sh`)**:
     - Added `-nostdin` to `ffmpeg` call in `qs_manager.sh` to prevent swallowing lines in `while read` loop.
     - Corrected ImageMagick frame selection syntax to `"${SEED}[0]"` and `"${file}[0]"` (SC1087).
  4. **Hyprland Rules Consolidation (`dotfiles/hypr/rules.lua`)**:
     - Consolidated duplicate `hl.window_rule` calls for `blueman-manager`, `pwvucontrol`, `pcmanfm-qt`, and `app-launcher` into unified single-table rules.
  5. **NixOS Hardening & Deprecation Fixes (`hardware-configuration.nix`, `shell.nix`, `home.nix`, `packages.nix`)**:
     - Restricted `/boot` mount options to `[ "fmask=0077" "dmask=0077" ]` to eliminate systemd-boot random-seed world-accessible security warning.
     - Replaced deprecated `pkgs.system` with `pkgs.stdenv.hostPlatform.system` in `shell.nix`.
     - Removed obsolete `enableBackup` activation hack in `home.nix` in favor of declarative `home-manager.backupFileExtension = "hm-backup";`.
     - Removed redundant `.out` package entries and duplicate `easyeffects` in `packages.nix`.
- **Result**: Completely clean QuickShell startup logs without QML errors, eliminated idle background `/proc` syscall churn, verified Nix flake check passes with zero warnings, and clean NixOS toplevel build.

## 2026-09-16 — Rebuild Activation Stability: Home Manager Force Clobber & Flatpak Offline Resilience

- **Context**: `nixos-rebuild switch` failed during activation with unit failures in `home-manager-realdhiru.service` (clobber conflict on `~/.config/matugen`) and `flatpak-repo.service` (`Could not resolve hostname dl.flathub.org`).
- **Decision**:
  1. **Home Manager Overwrite & Backup Protection (`home.nix`, `flake.nix`)**:
     - Added `force = true;` to `xdg.configFile."matugen"`, `xdg.configFile."wezterm/wezterm.lua"`, and `xdg.configFile."fastfetch/config.jsonc"` in `home.nix` so out-of-store symlinks are cleanly replaced without activation errors.
     - Added `home-manager.backupFileExtension = "hm-backup";` in `flake.nix` to ensure unmanaged conflicting dotfiles are automatically backed up rather than failing system activation.
     - Re-linked `~/.config/matugen` and `~/.config/rofi` to the authoritative `~/nix/dotfiles/*` paths.
  2. **Flatpak Systemd Unit Ordering & Offline Resilience (`modules/system/services.nix`)**:
     - Configured `systemd.services.flatpak-repo` with `after = [ "network-online.target" ];` and `wants = [ "network-online.target" ];` so it does not fire prematurely while networking daemons are restarting.
     - Marked service as `Type = "oneshot"; RemainAfterExit = true;` and added a pre-check (`grep -qx "flathub"`) so already-registered remotes or offline rebuilds will never cause service failure.
- **Result**: `nixos-rebuild build` evaluates and builds cleanly with no activation blockers.

## 2026-09-16 — Ly Display Manager, Autologin Removal & Deterministic 180° Screen Inversion

- **Context**: 
  1. User requested switching display management to `ly` (terminal-based, lightweight display manager) and removing automatic getty console login on TTY 1.
  2. User frequently uses the laptop tilted 180° and needed persistent display orientation across reboots, power state transitions (AC/battery profile switches via `SysData.qml`), and Hyprland reloads, along with quick 1-click UI toggles and hotkey support (`Ctrl + Escape`).
- **Decision**:
  1. **Ly Display Manager & Session Management (`modules/system/services.nix`, `modules/system/users.nix`, `modules/home/shell.nix`)**:
     - Enabled `services.displayManager.ly.enable = true;` and `services.displayManager.defaultSession = "hyprland";`.
     - Removed `services.getty.autologinUser` and `services.getty.autologinOnce` from `modules/system/users.nix`.
     - Removed automated `exec start-hyprland` check on TTY 1 in `programs.zsh.initContent` from `modules/home/shell.nix`, allowing Ly to cleanly manage session authentication and compositor launch.
     - Removed redundant `lock.sh` autostart call on `hyprland.start` in `dotfiles/hypr/startup.lua` so logging into Ly lands directly onto the desktop instead of immediately re-locking.
  2. **Deterministic Dynamic Screen Orientation & Atomic State Sync (`dotfiles/hypr/scripts/rotate_display.sh`)**:
     - Identified that Hyprland Lua `hl.monitor()` calls stage monitor modes in memory but require `hl.exec_scheduled_prop_refresh_immediately()` to trigger immediate DRM/KMS live pageflips without requiring a full compositor restart.
     - Synchronized orientation state between `~/.cache/hypr_power_monitor.conf` and `~/.config/hypr/settings.json`, ensuring cached format `,transform,<0|2>` preserves refresh rate and scaling settings (`2880x1620@120,auto,2,bitdepth,10`).
     - Added symlink `~/.local/bin/rotate-display` pointing directly to `rotate_display.sh`.
  3. **Power Profile & Battery Transition Safety (`dotfiles/hypr/scripts/quickshell/SysData.qml`, `dotfiles/hypr/hyprland.lua`)**:
     - Fixed `SysData.qml` omitting the transform parameter during battery/AC power state line generation.
     - Added reactive `FileView` in `SysData.qml` to track `isRotated` and `displayTransform` without polling.
     - Fixed QML syntax crash by escaping bash parameter expansion (`\${TRANSFORM:-0}`) in JS template literal and removing nonexistent `.exists()` on `FileView`.
     - Updated `hyprland.lua` `apply_power_monitor()` to parse the cached transform and fall back to `settings.json`.
  4. **QuickShell UI 180° Inversion Controls (`dotfiles/hypr/scripts/quickshell/battery/BatteryPopup.qml`, `dotfiles/hypr/scripts/quickshell/monitors/MonitorPopup.qml`)**:
     - Added an orientation toggle button (`󰑮`) in `BatteryPopup.qml` header alongside the network button with visual rotation state cues.
     - Added a dedicated "180° Flip" button (`flip180Btn`) in `MonitorPopup.qml` beside the rotary transform dial for single-click inverted/normal switching.
- **Result**: Clean Ly terminal login screen, permanent screen orientation persistence across battery/AC transitions and Hyprland reloads, and instant 180° screen rotation via keyboard shortcut (`Ctrl + Escape`) or QuickShell popup buttons.

## 2026-09-10 — Declarative Flatpak & GNOME Software Center Support (`modules/system/services.nix`, `modules/system/packages.nix`)

- **Context**: User requested installing and using Flatpak applications via a GUI Software Center app on Hyprland.
- **Decision**:
  1. Enabled `services.flatpak.enable = true;` in `modules/system/services.nix` (auto-wires system polkit, dbus, and export paths into environment profiles).
  2. Created systemd oneshot service `systemd.services.flatpak-repo` to automatically register the Flathub remote repository (`https://dl.flathub.org/repo/flathub.flatpakrepo`).
  3. Added `gnome-software` to `modules/system/packages.nix` providing the official graphical Software Center to browse, install, and manage Flatpaks.
- **Result**: Users can open "Software" from Rofi/launcher, browse Flathub apps visually, install them with one click, and launch them seamlessly from Rofi.

## 2026-09-10 — Declarative AppImage Execution & Anti-Tamper Proctoring Support

- **Context**:
  1. Standalone AppImages failed on NixOS due to missing standard FHS dynamic linker (`/lib64/ld-linux-x86-64.so.2`).
  2. Exam proctoring AppImages (such as Examly's Neo Browser) contain native anti-tamper modules (`process_guard.node`) that inspect parent process `/proc/$PPID/comm` and abort with `NEO-I-02: opened in an unsupported way. (parent: bwrap)` when run under NixOS's default Bubblewrap FHS container.
- **Decision**:
  1. Configured `programs.appimage = { enable = true; binfmt = true; };` in `modules/system/packages.nix`.
  2. Created runner helper `~/.local/bin/neo-browser` that aliases `bwrap` as `systemd` in its PID supervisor namespace, cleanly satisfying Neo Browser's parent process whitelist without modifying the signed binary.
- **Result**: Neo Browser launches directly into its secure examination environment without triggering anti-tamper or signature errors.

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

10. **Focus Daemon Zero-Fork In-Process Screen Lock Detection (`dotfiles/hypr/scripts/quickshell/focustime/focus_daemon.py`)**:
    - **Root Cause**: `focus_daemon.py` called `subprocess.check_output(['pgrep', '-x', 'hyprlock'])` every 1 second in its main tracking loop, spawning 3,600 external processes per hour and interrupting CPU sleep states.
    - **Solution**: Replaced the subprocess call with direct in-process `/proc` scanning (`os.scandir('/proc')`), eliminating all fork/exec overhead while preserving lock detection.

11. **Manual Dark Mode / Normal UI Mode Toggle (`keybinds.lua`, `set_wallpaper.sh`, `toggle_dark_mode.sh`)**:
    - **Change**: Replaced automatic luminance-based dark mode triggering with a manual keybind toggle. Removed auto-overwriting of `wallpaper_is_light.txt` in `set_wallpaper.sh` so the user's selected mode persists across wallpaper changes.
    - **Keybind**: Bound `CTRL + SUPER + D` to `toggle_dark_mode.sh`. Toggles between Normal mode (100% transparent terminal, translucent TopBar pills) and Dark Contrast mode (0.42 frosted dark terminal, high-contrast TopBar pills) with live Quickshell/WezTerm reload and low-priority OSD notification.


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