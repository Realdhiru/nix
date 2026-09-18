# Decisions Log

Why things are the way they are. **Read before touching power, audio,
wallpaper, or quickshell.** New entries go on top; never delete a decision —
supersede it.

## 2026-09-18 — Boot Critical Chain Decoupling, Post-Password Latency & NTFS UDisks2 Configuration

- **Context:**
  1. Boot time was analyzed via `systemd-analyze`. `display-manager.service` (Ly) was gated behind `systemd-user-sessions.service`, which was waiting for `network.target` and NetworkManager, adding unnecessary seconds before the login prompt appeared on a single-user offline-capable laptop.
  2. Post-password desktop loading into Hyprland was delayed by an unneeded `hyprctl reload` fired during cold boot by `set_wallpaper.sh`, sequential startup of QuickShell behind wallpaper scripts, and a duplicate `wallpaper_watcher.sh` daemon invocation.
  3. The Windows C: partition failed to mount with `volume is dirty and "force" flag is not set!`, and UDisks2 prevented passing `force` by default.
- **Decisions:**
  1. **Boot Target Decoupling (`services.nix`)**:
     - Decoupled `systemd.services.flatpak-repo` from `multi-user.target` by setting `wantedBy = [ "network-online.target" ]`. Flathub repo checks run in the background after networking is active rather than holding up userspace boot.
     - Overrode `systemd.services.systemd-user-sessions.after` to only wait on `remote-fs.target` and `nss-user-lookup.target`, decoupling local console sessions from `network.target`.
  2. **Desktop Post-Password Latency (`dotfiles/hypr/startup.lua`, `set_wallpaper.sh`)**:
     - Removed redundant `hyprctl reload` on cold boot in `set_wallpaper.sh`; dynamic evaluation is only triggered when explicitly recovering from a killed wallpaper state.
     - Moved QuickShell initialization to the top of `startup.lua` to render the TopBar and UI concurrently.
     - Removed duplicate `wallpaper_watcher.sh` invocation in `startup.lua` since systemd manages it as a user service.
  3. **UDisks2 NTFS Dirty Bit Tolerance (`services.nix`)**:
     - Injected `/etc/udisks2/mount_options.conf` defining `ntfs_allow = ...,force`, allowing user-level file managers and `udisksctl` to mount dirty NTFS partitions safely.

## 2026-09-18 — Multi-User Parameterization & Domain Script Consolidation (Omarchy Architecture)

- **Context:**
  1. The user identified that personal credentials (`realdhiru` and `/home/realdhiru`) were hardcoded in over 50 locations across Nix modules, Lua scripts, JSON configs, and Matugen templates, preventing clean public distribution on GitHub.
  2. Over 26 fragmented, single-function shell scripts existed in `dotfiles/hypr/scripts/` with tight interdependencies, racing lockfiles, and duplicate logic.
  3. A rebuild failed during `home-manager` switch due to an unmanaged clobber collision on `~/.local/share/icons/buuf-nestort`.
- **Decisions:**
  1. **Single Source User Parameterization (`user.nix`)**:
     - Introduced `user.nix` at the root of the configuration defining `username`, `name`, and `hostname`.
     - Injected `user` into `specialArgs` in `flake.nix`. All NixOS user accounts, sudoers rules, and Home Manager profiles derive strictly from `user.username`.
     - Completely banished `/home/username` from dotfiles: all Lua scripts use `os.getenv("HOME")`, Matugen uses `~` (natively supported by Matugen 4.2.0), and settings use dynamic path expansion in `Config.qml`.
  2. **Multi-Tool CLI Architecture**:
     - Consolidated 6 wallpaper scripts into `wallpaper.sh [set|boot|kill|ensure|thumb|watch|clean]`.
     - Consolidated 4 power/sleep/lock scripts into `power.sh [lock|suspend|resume|lid|inhibit]`.
     - Maintained lightweight delegate wrappers for backwards-compatibility so background services and IPC calls remain unbroken.
  3. **Centralized QuickShell Base (`PopupCard.qml`)**:
     - Extracted popup background rectangles, opacity, borders, and specular highlights into `PopupCard.qml`, enabling whole-shell styling adjustments from a single file.
  4. **Home Manager Link Force (`theme.nix`)**:
     - Set `xdg.dataFile."icons/buuf-nestort".force = true;` to guarantee idempotent declarative icon linking without clobber stops.
  5. **Dynamic Hostname Centralization (`user.nix`, `hosts/nixos/default.nix`)**:
     - Replaced hardcoded `networking.hostName = "vivobook";` with `networking.hostName = user.hostname;` wired directly to `user.nix`. Set default hostname to `NixOS`.
  6. **Ly Display Manager Log Hygiene (`modules/system/services.nix`)**:
     - Configured `services.displayManager.ly.settings.session_log = null;`. Ly's legacy behavior of creating empty `~/ly-session.log` in `$HOME` is completely disabled since systemd journal (`journalctl --user`) and Hyprland's instance runtime directory manage session logs natively.

## 2026-09-17 — NetworkManager Hotspot Backend UUID Hardening & Hardware Concurrency Boundaries

- **Context:**
  1. QuickShell Hotspot controller was falsely reporting `OFF` even when the AP was actively running in NetworkManager, and editing SSID/password had no effect.
  2. The Hotspot settings drawer in `BatteryPopup.qml` was opening by default on widget launch and clipping internal controls.
  3. The user investigated whether single-adapter Wi-Fi repeating (simultaneous STA client + AP hotspot) could be supported on their Intel wireless chip (`wlo1`) to share campus Wi-Fi (`KIET`) to a mobile phone.
- **Root Cause & Decisions:**
  1. **UUID-Based Backend Isolation (`hotspot_control.sh`)**:
     - Investigated `hotspot_control.sh` failures using `bash -x`. Discovered three duplicate NetworkManager profiles named "Hotspot", causing `nmcli -s -g 802-11-wireless.mode connection show Hotspot` to return multiple lines (`mode=$'ap\n\nap\n\nap'`), failing string equality tests (`[ "$mode" = "ap" ]`).
     - Rewrote `get_active_hotspot_conn` and `get_hotspot_conn` to query and operate strictly on unique connection UUIDs (`nmcli -t -f UUID,TYPE connection show ...`), making profile queries immune to duplicate names. Purged orphaned duplicate profiles.
  2. **Hotspot Drawer Lifecycle & Neutral UI (`BatteryPopup.qml`)**:
     - Added `window.showHotspotMenu = false` in `showWidget()`, ensuring the drawer is collapsed by default on widget launch.
     - Changed drawer height from rigid hardcoded pixel bounds to dynamic `hotspotContentCol.implicitHeight + window.s(28)`, preventing clipping.
     - Removed Wi-Fi glyphs and replaced dynamic green/mauve outlines with neutral `surface2` borders and white text.
  3. **Single-Radio Hardware Boundary Decision (`#channels <= 1`)**:
     - `iw list` confirms adapter capabilities: `#{ managed } <= 1, #{ AP } <= 1, #channels <= 1`.
     - The physical radio contains only one synthesizer. Concurrent Wi-Fi client reception and Hotspot transmission are physically impossible unless both the upstream router and hotspot share the exact same channel/frequency.
     - On dynamic/roaming campus networks (`KIET`), the router negotiates 5 GHz DFS channels (e.g. Channel 64 / 5320 MHz) and actively steers clients across channels. Forcing a virtual `ap0` interface on dynamic DFS channels causes immediate disconnection whenever the router shifts channels, and mobile phones cannot connect to 5 GHz DFS beacons.
     - **Decision:** Rejected custom `hostapd` virtual `ap0` Wi-Fi repeating for single-radio roaming use. Retained native NetworkManager hotspot architecture: acts as an AP to share wired Ethernet or USB tethering over Wi-Fi, and automatically restores client Wi-Fi (`KIET`) within 1 second upon hotspot deactivation.

## 2026-09-17 — Fuzzel HiDPI Rescaling, On-Demand Focus Dismissal & Non-Destructive Reloads

- **Context:**
  1. Fuzzel was not dismissing when clicked outside because Wayland layer-shell defaults to `keyboard-focus = exclusive`, preventing external surfaces from receiving clicks or focus.
  2. On a global 2x scale display, Fuzzel's UI (14pt font, 36px line height, 44 chars width) appeared disproportionately huge next to QuickShell's sleek, compact widgets.
  3. Running `reload.sh` executed `pkill -f Shell.qml` and `sleep 0.3`, unmapping all Wayland surfaces and causing a jarring black screen blink / cold reboot on every config reload.
  4. Verbose notification texts (e.g. multi-line gaming mode messages) were overflowing the TopBar ticker.
  5. Toggling Hotspot left Wi-Fi client mode disconnected after Hotspot was disabled, leaving the user with no network connection.
- **Root Cause & Decisions:**
  1. **Fuzzel On-Demand Keyboard Focus (`fuzzel.ini`)**:
     - Configured `keyboard-focus = on-demand` and `exit-on-keyboard-focus-loss = yes`. This allows clicks on windows, bars, or desktop to receive focus, causing Fuzzel to exit cleanly on outside clicks.
  2. **HiDPI Proportion Harmony (`fuzzel.ini`, `fuzzel_menu.sh`)**:
     - Reduced Fuzzel typography and padding to match QuickShell: font size 10pt (file search 9.5pt), line height 22px, width 32 chars, padding 14px/10px/6px, corner radius 12px.
  3. **Unified Fuzzel Runner (`fuzzel_menu.sh`)**:
     - Consolidated separate launcher and file search scripts into `fuzzel_menu.sh {app|file}` with automatic solid background fallback for power-saver and zero-blur states.
  4. **Non-Destructive Compositor Reloading (`reload.sh`)**:
     - Removed the destructive `pkill` and sleep cycle from standard Hyprland reloads. QuickShell remains resident across `hyprctl reload`, eliminating screen blinking. QuickShell cold boot only occurs if it is not currently running or if `--quickshell` is explicitly passed.
  5. **Zero-Bloat Notifications (`toggle_gaming_mode.sh`, `hotspot_control.sh`)**:
     - Replaced verbose text strings with concise `"ON"` and `"OFF"` alerts to keep the TopBar clean.
  6. **Hotspot Auto Wi-Fi Recovery (`hotspot_control.sh`, `BatteryPopup.qml`)**:
     - Saved active Wi-Fi SSID prior to starting Hotspot. On Hotspot shutdown, automatically re-associates with the saved Wi-Fi network (`nmcli connection up "$PREV_SSID"`). Fixed AP profile detection with process substitution. Wired left-click to direct Hotspot toggling.

- **Context:**
  1. In the file finder, piping all files from `fd` on startup presented an 8-item initial list that looked like unwanted "history" or visual clutter. The user requested starting with only a search prompt row, dynamically expanding only when a query matches.
  2. The brightness and volume sliders in the battery popup were still not reflecting live system state, percentages next to the sliders were unwanted, and the remaining battery runtime badge needed to sit squarely in between the "Notifications" heading and the notification mute icon.
- **Root Cause & Decisions:**
  1. **Fuzzel Interactive Dismissal & Solid Background (`fuzzel.ini`, `fuzzel_app_launcher.sh`, `fuzzel_file_search.sh`)**:
     - `exit-on-keyboard-focus-loss = no` was preventing users from clicking outside Fuzzel to dismiss it. Re-enabled `exit-on-keyboard-focus-loss = yes` so clicking outside anywhere dismisses the launcher immediately.
     - Added dynamic `--background-color=111111ff` solid rendering when blur/transparency is disabled (in power-saver, gaming mode, or wallpaper killed), fixing unreadable text and eliminating GPU alpha-blending.
  2. **State Persistence Across Hyprland & QuickShell Reloads (`SysData.qml`, `reload.sh`, `set_wallpaper.sh`)**:
     - Previously, QuickShell reloads forced `powerProfile = "balanced"` on battery via `_reconcileStartupProfile`, wiping the user's manual `power-saver` selection.
     - Resolved by persisting the profile to `~/.cache/qs_power_profile` and reading it upon initialization via `FileView`.
     - In `reload.sh`, Hyprland reloads now re-evaluate active visual state (`wallpaper_killed`, `gaming_mode`, `power-saver`), preventing visual effects from resetting to default translucency.
  3. **Dedicated Efficiency / Gaming Mode (`toggle_gaming_mode.sh`, `keybinds.lua`)**:
     - Bound `Super + Shift + G` to toggle zero-latency compositing: forces 100% opaque windows, disables dual-kawase blur, disables drop shadows, enables Direct Scanout (`render:direct_scanout = 2`), enables Adaptive Sync (`misc:vrr = 1`), and enables asynchronous tearing (`general:allow_tearing = true`).
     - Preserves animations (`not animations`) and wallpapers (`not wallpapers`). Avoids artificial battery-draining CPU frequency locks when on battery.
  4. **Dynamic GPU Blur, Shadow, Opacity & Animation Bypass (`kill_wallpaper.sh`, `set_wallpaper.sh`, `SysData.qml`)**:
     - Dual-kawase blur shaders and alpha-translucent window compositions running over solid black backgrounds draw ~1.2W–2.0W of wasted GPU package power during typing, window scrolling, and animations.
     - `kill_wallpaper.sh` dynamically executes `hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0 }, animations = { enabled = false } })"` and `hl.window_rule({ match = { class = '.*' }, opacity = '1.0 override 1.0 override' })` to force 100% opaque windows and bypass all animations and shaders, setting state flag `~/.cache/wallpaper_killed`. This allows hardware occlusion culling and eliminates multi-pass alpha blending.
     - `set_wallpaper.sh` re-enables blur, shadows, animations, and reloads window rules (`hyprctl reload`) to restore window transparency (unless actively in `power-saver`).
     - `SysData.qml` mirrors these visual overrides on `power-saver` mode and cleanly restores them upon exiting `power-saver`.
  5. **File Finder Keybind Collision Resolution (`keybinds.lua`)**:
     - `Super + Shift + F` was bound to both the file finder and Hyprland's native window pinning (`hl.dsp.window.pin()`), resulting in a dispatch race.
     - Resolved by remapping the file finder cleanly to `Super + Space` and preserving window pinning on `Super + Shift + F`.
  6. **Linear Stagger Cascade & Snappy Popup Morphs (`TopBar.qml`, `Main.qml`)**:
     - The previous 500ms `OutBack` scale/translate animation in `TopBar.qml` caused top bar icons to feel rubbery and sluggish. Replaced with 220ms `OutCubic` transitions with a uniform 25ms delay step across workspace Kanji and tray items.
     - Reduced `Main.qml` morph and shift durations from 230ms to 160ms for instant popup openings.
  7. **QuickShell Startup Hitch Elimination (`TopBar.qml`, `Main.qml`)**:
     - Investigated the 1–2 second initial hang when launching or refreshing QuickShell.
     - Identified two root causes: (a) `TopBar.qml` was gating right-bar rendering behind an 800ms fallback timeout waiting for battery capacity changes, and (b) `Main.qml` was executing `preloadStaggerTimer` immediately on `Component.onCompleted`, instantiating 9 heavy popup widgets sequentially every 150ms and choking the single-threaded QML runtime for 1.35 seconds.
     - Resolved by making `isDataReady: true` immediately in `TopBar.qml` and deferring widget preload in `Main.qml` to a 6-second post-startup idle timer (`preloadIdleTimer`). The top bar now appears with 0ms hitching.
  8. **Native NetworkManager Hotspot Integration (`services.nix`, `users.nix`, `hotspot_control.sh`)**:
     - Removed artificial `wifi-ap-interface` systemd unit and manual `ap0` sudo rules, which caused `wpa_supplicant` to grab `ap0` as a client station and lock out the physical device with `EBUSY`.
     - Aligned with native NetworkManager D-Bus and CLI architecture (`nmcli device wifi hotspot`), letting NetworkManager manage wireless states directly.
  9. **Matugen Dynamic Color Integrity (`MatugenColors.qml`)**:
     - Preserved the dedicated `colors_wait.sh` inotify watcher for `qs_colors.json`. Atomic file renames from external tools are reliably captured in <10ms without dropping file descriptors.
  10. **Hotspot Pill Text Contrast & Header Geometry (`BatteryPopup.qml`)**:
     - Fixed Hotspot pill text color by binding to `window.text` (crisp white/cream) instead of `window.subtext1` (dark charcoal), resolving the dark/unreadable text issue.
     - Permanently expanded the Hotspot pill button with constant opacity, eliminating the collapsed 38px sliver and keeping the central battery timer pill centered and balanced.
  11. **Logoff Button Immediate Execution (`BatteryPopup.qml`)**:
     - Added direct tap/click `hyprctl dispatch exit` execution to the Logoff capsule, removing hold-to-confirm friction while retaining safety holds on Shutdown and Reboot.

## 2026-09-16 — Complete Rofi Decommissioning, Centered Fuzzel UI, and QuickShell Battery Overhaul

- **Context:** The Fuzzel coexistence trial succeeded. The user requested:
  1. Completely decommissioning Rofi and re-assigning the primary app launcher bind `Super + A` to Fuzzel.
  2. Centering both Fuzzel and the file finder on-screen (`anchor = center`) with fade animations.
  3. Configuring the file finder so that pressing Enter on a result opens its parent directory/location in `pcmanfm-qt` instead of opening the file.
  4. Overhauling the QuickShell battery widget (`BatteryPopup.qml`): making brightness/volume sliders and numerical presenters reactive to live keyboard changes, removing the Wifi and rotate buttons, fixing the non-working logout button and reordering action capsules (`Logoff`, `Sleep`, `Shutdown`, `Reboot`), relocating battery time remaining to the notification header, and condensing widget height.
- **Root Cause & Decisions:**
  1. **Rofi Decommissioning**: Retired `rofi` from `modules/system/packages.nix`, deleted the `xdg.configFile."rofi"` Home Manager symlink, removed old rofi layer/window rules, and bound `Super + A` to `pkill fuzzel || fuzzel`.
  2. **Centered Geometry & Directory Opening**:
     - Configured `anchor = center`, `x-margin = 0`, `y-margin = 0` in `fuzzel.ini` and Hyprland layer rule `animation = fade` on `^(fuzzel|launcher)$`.
     - In `fuzzel_file_search.sh`, updated Enter action: `DIR_PATH=$(dirname "$SELECTED_FILE"); pcmanfm-qt "$DIR_PATH" &`.
  3. **QuickShell Battery Telemetry & Presenters**:
     - QuickShell lost volume reactivity when sink instances re-initialized. Replaced brittle `target` connections with direct declarative bindings (`pipewireVol`, `pipewireMuted`) on `Pipewire.defaultAudioSink.audio`.
     - Added a dedicated 300ms `briLivePoller` (`brightnessctl -m`) running only while the popup is visible and not being dragged.
     - Added bold percentage (`%`) readouts to the right of both brightness and volume slider bars.
  4. **Action Row & Layout Condensation**:
     - Fixed logout failure caused by bash quoting `~` by using `bash $HOME/.config/hypr/scripts/exit.sh`.
     - Reordered bottom action row to exact order: Logoff (`󰍃`), Sleep (`ᶻ 𝗓 𝗓`), Shutdown (``), Reboot (`󰑓`).
     - Relocated remaining battery runtime into the Left-side notification header next to the DND button.
     - Removed empty top row on the right column, shifted the central battery ring up (`anchors.verticalCenterOffset: window.s(-140)`), and condensed popup height in `WindowRegistry.js` from `760` to `660`.
- **Supersedes:** `2026-09-16 — Fuzzel Application Launcher & Fast File Search Coexistence Trial`

## 2026-09-16 — Fuzzel Application Launcher & Fast File Search Coexistence Trial

- **Context:** The user requested testing Fuzzel to replace Rofi for battery savings and performance, while demanding exact visual parity (dark frosted glass), dual vertical/horizontal navigation, and interactive file searching, before removing Rofi.
- **Decision:**
  1. **Safe Side-by-Side Coexistence**: Retained `rofi` on `Super + A` completely untouched. Added `fuzzel` and `fd` to `environment.systemPackages` in `modules/system/packages.nix`.
  2. **Exact Glassmorphism Theming**: Created `dotfiles/fuzzel/fuzzel.ini` matching `dotfiles/rofi/theme.rasi` aesthetics:
     - 14px JetBrains Mono font (`JetBrainsMono Nerd Font:size=14`).
     - `#00000073` background (`rgba(0,0,0,0.45)`), 16px corner radius, 1px subtle white border (`#ffffff24`), and left screen offset (`anchor = left`, `x-margin = 120`).
     - Hyprland layer-shell rules: `blur = true`, `ignore_alpha = 0.1`, `animation = slide left`.
  3. **Dual Horizontal & Vertical Navigation**:
     - Vertical: `Up` / `Down`, `Control+p` / `Control+n`, and Vim-style `Control+k` / `Control+j`.
     - Horizontal: `Left` / `Right` mapped to `prev-page` / `next-page` for instant paging across items.
  4. **High-Speed File Finder (`fuzzel_file_search.sh`)**:
     - Built `dotfiles/hypr/scripts/fuzzel_file_search.sh` using `fd` to stream user files (`~/Documents`, `~/Downloads`, `~/Pictures`, `~/Videos`, `~/Music`, `~/nix`, `~/Desktop`) into `fuzzel --dmenu` and open matches with `xdg-open`. Bound to `Super + Shift + F`.
  5. **Keybindings**: Bound Fuzzel app launcher to `Super + Space`, leaving `Super + A` on Rofi.


## 2026-09-16 — QuickShell Wallpaper Picker Interactive Delete & Ingest-On-Close Architecture

- **Context:** When searching and testing wallpapers in QuickShell's WallpaperPicker, downloaded wallpapers were immediately shifted into color subdirectories (`blue/`, `warm/`, etc.) within 1 second by `auto_organize.py`, triggering auto-commits and GitHub pushes for wallpapers the user was only previewing/testing. A 30-minute background timer was proposed but rejected due to unnecessary laptop battery drain (preventing deep CPU C-states) and poor UX.
- **Root Cause:**
  1. `wallpaper-watcher.service` reacted to `CLOSE_WRITE` instantly and organized any newly written file in `~/Pictures/Wallpapers/` without checking if the user was actively testing wallpapers in QuickShell.
  2. QuickShell had no keyboard delete action to quickly discard unwanted tested wallpapers from the screen/disk.
  3. Git staging in `auto_organize.py` used `git add -A`, risking staging loose inbox files prematurely.
- **Decision:**
  1. **Zero-Battery Ingest-On-Close**:
     - QuickShell sets a lightweight run flag (`/run/user/$UID/quickshell/wallpaper_picker/picker_active`) when the picker is opened.
     - `auto_organize.py` detects this flag and defers shifting root inbox files into color subdirectories and Git while the picker is active.
     - On picker close (`onVisibleChanged: false` / `Component.onDestruction`), the flag is cleared and `auto_organize.py` runs once, committing and pushing only the wallpapers the user decided to keep.
  2. **Keyboard-Driven `Delete` Key**:
     - Added a `Delete` key shortcut in `WallpaperPicker.qml` (disabled when typing in search input).
     - Pressing `Delete`:
       - Restores the previous wallpaper via `~/.cache/previous_wallpaper.txt` (recorded by `set_wallpaper.sh`) if the deleted item was currently applied.
       - Purges the downloaded media file from `~/Pictures/Wallpapers/` and its search thumbnail from `search_thumbs/` (or runs `auto_organize.py --delete` in local tabs).
       - Removes the item from the active ListModel with zero layout jump and advances focus.
       - Shows an instant "Wallpaper deleted" notification toast in the drawer.
  3. **Safe Git Staging**:
     - Replaced `git add -A` in `auto_organize.py` with explicit staging (`README.md`, `previews/`, and the specific categorized file), ensuring loose inbox wallpapers are never committed accidentally.
- **Result:** Instant zero-friction deletion of unwanted tested wallpapers from the keyboard with zero battery drain and clean Git history.

## 2026-09-16 — Wallpaper Architecture Alignment, Real-Time Watcher & Filter Simplification

- **Context:** The wallpaper repository (`~/Pictures/Wallpapers`) adopted a categoric directory architecture (`dark/`, `blue/`, `warm/`, `green/`, `purple/`, `light/`, `gifs/`, `videos/`) with generated previews in `previews/`. QuickShell's wallpaper picker had legacy color categories ("Red", "Orange", "Yellow", etc.), indexed duplicate 640px WebP files from `previews/` (doubling flat cache from 218 to 435), and Hyprland's `wallpaper_watcher.sh` only listened to deletions. Furthermore, the widget's `width: 0` hiding hack in `ListView` created hundreds of ghost items that broke scrolling momentum and navigation.
- **Root Cause:**
  1. `wallpaper_thumbnail.sh` did not exclude `previews/` or `scripts/`, generating redundant low-res thumbnails and polluting `flat/`.
  2. `wallpaper_watcher.sh` watched solely `-e delete -e moved_from`. Any new wallpaper added or moved between categories failed to trigger cache generation until a manual run or reboot.
  3. In `WallpaperPicker.qml`, filtering was implemented by setting non-matching delegate `width: 0` and `opacity: 0`. QtQuick `ListView` still counted these in the index range, causing jumpy scrolling and blank gaps.
  4. Subjective color shade categories (Dark, Blue, Warm, Green, Purple, Light) provided minimal utility across a curated library of ~220 items while cluttering the top bar.
- **Decision:**
  1. **Exclude Previews and Scripts**: In `wallpaper_thumbnail.sh`, strictly excluded `previews*` and `scripts*` from indexing and purged any existing symlinks pointing to them.
  2. **Unbuffered Full-Event Watcher**: Updated `wallpaper_watcher.sh` to monitor `-e create -e delete -e moved_from -e moved_to -e close_write` using `stdbuf -oL` with a 0.5s drain debounce and `flock -w 30 200` serialized thumbnail generation.
  3. **Option A: Clean Filter Set**: Removed the 6 color shade dots. Retained 4 purposeful tabs: **All**, **GIFs**, **Videos**, and **Search**.
  4. **Dedicated Model Filtering**: Replaced `width: 0` ghost delegates with dedicated sub-models (`localProxyModel`, `gifsProxyModel`, `videosProxyModel`, `searchProxyModel`). Every item in the active model is 100% visible, eliminating ghost items and ensuring silky-smooth scrolling.
- **Result:** Exact 1-to-1 parity between repository wallpapers and QuickShell picker (222 files, 0 duplicate previews). Smooth, gap-free scrolling across All, GIFs, and Videos with real-time file synchronization.

## 2026-09-16 — QuickShell Wallpaper Picker Online Search Model Churn & Download Coordination

- **Context:** Searching in QuickShell's WallpaperPicker caused active preview scrolling to break and continuously snap back to the start (`index = 0`), and downloading search wallpapers failed or hung indefinitely.
- **Root Cause:**
  1. `syncSearchModel()` executed `sortListModel(searchProxyModel)` every time a thumbnail finished downloading. `sortListModel()` executed `model.clear()` and `model.append()`, destroying all active delegate instances, losing user scroll position, and snapping `ListView` back to `index = 0`.
  2. `isScrollingBlocked` locked out mouse wheel scrolling, arrow key navigation, drag interaction, and preview clicks whenever `FolderListModel.status === Loading` during file arrival.
  3. Background `wallpaper-watcher.service` (`auto_organize.py`) was immediately intercepting downloaded wallpapers in `~/Pictures/Wallpapers/` and moving them into shade subfolders (`dark/`, `blue/`, etc.). Because `WallpaperPicker.qml` only checked the root folder non-recursively, `isDownloadingWallpaper` stayed stuck on `true`. Furthermore, `current_wallpaper.txt` pointed to the vanished root path, causing Hyprland's `wallpaper_watcher.sh` to treat the active wallpaper as deleted and trigger `boot_wallpaper.sh`.
- **Decision:**
  1. **Non-Destructive Model Append**: Replaced `model.clear()` and `sortListModel()` in `syncSearchModel()` with Set-based incremental deduplication. New search previews append cleanly to the end of `searchProxyModel` in arrival order without disturbing existing delegates, active item selection, or scroll position.
  2. **Unrestricted Interaction**: Disabled `isScrollingBlocked` so users can scroll previews, navigate with arrow keys, and click items at any time during background search streaming.
  3. **Managed Download Lifecycle**: Bound wallpaper downloads to a QuickShell `Process { id: downloadProc }` with timeout guards, MIME type validation, and thumbnail fallback.
  4. **Active Wallpaper State Preservation**: Updated `auto_organize.py` to rewrite `~/.cache/current_wallpaper.txt` and `last_wallpaper.txt` whenever an active wallpaper is moved into a category subfolder, preventing false resets by Hyprland's watcher, and triggered `wallpaper_thumbnail.sh` to keep `flat/` symlinks in sync.
- **Result:** Preview scrolling is completely smooth and continuous while DuckDuckGo results stream in; downloads complete reliably without hanging or resetting wallpapers.

## 2026-09-16 — Ly Display Manager Migration & Live DRM Monitor Transform Architecture

- **Context:** User requested migrating from getty autologin on TTY 1 to the lightweight terminal display manager `ly`, and fixing screen rotation persistence so 180° inverted orientation is preserved across power profile switches, reboots, and Hyprland reloads, with 1-click UI triggers.
- **Decision:**
  - **Ly over Getty Autologin**: Configured `services.displayManager.ly.enable = true` and `services.displayManager.defaultSession = "hyprland"`. Removed getty autologin and the TTY1 zsh `exec start-hyprland` hook. Ly provides a clean, minimal TTY login screen with PAM integration while letting systemd handle session teardown cleanly. Also removed redundant `lock.sh` invocation from `dotfiles/hypr/startup.lua` (`hl.on("hyprland.start")`), ensuring logging into Ly transitions directly to the desktop without an immediate lockscreen prompt.
  - **Hyprland Lua Dynamic Property Refresh**: Discovered that calling `hl.monitor()` via `hyprctl eval` only stages the monitor configuration in the Lua runtime. To commit KMS modeset and DRM plane rotation live to the kernel display pipe without restarting Hyprland, `hl.exec_scheduled_prop_refresh_immediately()` must be called immediately following `hl.monitor()`.
  - **Power State & Monitor Transform Cohesion**: `SysData.qml` previously calculated `TRANSFORM_STR` during power mode changes (AC vs Battery) but omitted it when generating `~/.cache/hypr_power_monitor.conf`. This caused any power plug/unplug event to reset the display transform back to 0. Added `,transform,$TRANSFORM_VAL` to the generated cache line, added dynamic `FileView` tracking in QuickShell, and updated `hyprland.lua` to reliably deserialize the transform token.
  - **Atomic Rotation Script (`rotate_display.sh`)**: Centralized rotation logic into `rotate_display.sh` and symlinked to `~/.local/bin/rotate-display`. The script queries `~/.cache/hypr_power_monitor.conf` as the ground truth (avoiding KMS pageflip race conditions in `hyprctl monitors -j`), writes state updates atomically, and broadcasts `Prop.displayTransform` changes to QuickShell.
  - **QuickShell Controls**: Added a 180° toggle button in `BatteryPopup.qml` and `MonitorPopup.qml` to provide fast graphical access alongside the existing `Ctrl + Escape` keybinding.
- **Result:** Ly manages authentication reliably; orientation is 100% persistent across power events and restarts, and 180° screen inversion toggles instantly without display flicker or lockups.

## 2026-09-15 — Full Waybar & QuickShell TopBar Aesthetic and Interaction Parity

- **Context:** The user demanded full aesthetic and functional parity between Waybar on Niri and their QuickShell TopBar (`TopBar.qml`).
- **Decision:**
  - **Centered Island Geometry**: In QuickShell, `globalCenterContainer` is `anchors.centerIn: parent`. Migrated all Waybar modules from separate left/center/right boxes into `modules-center` and styled each module as an independent glass capsule (`alpha(@surface_bright, 0.35)`, `1px solid alpha(@on_surface, 0.05)`, `border-radius: 14px`).
  - **Kanji Workspaces & Empty Filtering**: Applied Japanese Kanji numerals `一` through `十` using `"Noto Sans CJK JP, JetBrains Mono"`. Active workspace is a solid Mauve pill with dark crust text. Emptied workspaces are styled with `min-width: 0`, `padding: 0`, `font-size: 0` to completely hide them, reproducing QuickShell's occupied-only workspace rendering.
  - **Grouped Clock & Date**: Created a horizontal group `group/clock` combining `clock#time` (large bold 13.5px Mauve `HH:mm`) with `clock#date` (stacked 2-line day of week and month-day). Click triggers `qs_manager.sh toggle calendar`.
  - **Battery Accent Capsule (`sysBatPill`)**: Created `group/sys` with an inner `#battery` solid Mauve pill with dark crust text. Click triggers `qs_manager.sh toggle battery`.
  - **QuickShell Popups on Niri**: Integrated `calendar/` and `battery/` into `~/.config/niri/quickshell/` and registered them in `WindowRegistry.js`, completing popup parity across compositors without touching `dotfiles/hypr/`.
  - **Compact HiDPI Scale & Alignment**: Scaled bar height to 34px and proportional button dimensions to prevent oversized elements on 2.0x scaled 1440 logical resolution.
  - **Bloat-Free Screenshot Architecture**: Replaced Hyprland-dependent `grimblast` with `dotfiles/niri/scripts/screenshot.sh` mapped to `Print`, `Mod+Shift+Z`, and `Mod+Ctrl+Shift+Z` (`--freeze`), using direct `slurp` + `grim` + `wl-copy`.
- **Result:** Pixel-perfect visual and interactive alignment with QuickShell TopBar and instant screenshot workflow.

## 2026-09-15 — Niri System Hardening, Daemon Deduplication & Portal Isolation

- **Context:** Diagnostic pass over Niri revealed multiple process leaks (multiple Waybars and `swaync-client` instances), high idle CPU, QuickShell path references leaking to Hyprland, XDG portal fallback issues (Hyprland portal running under Niri), missing `xwayland-satellite`, and a Polkit race condition causing a failed systemd unit.
- **Decision:**
  - **Process Lifecycle in `reload.sh`**: Changed `pkill -x waybar` to `pkill -f "waybar"` and `pkill -f "swaync-client -swb"` to account for NixOS `.waybar-wrapped` process names. Daemonized Waybar and QuickShell restarts using `setsid -f`.
  - **Portal Backend Isolation**: Added `~/.config/xdg-desktop-portal/niri-portals.conf` configuring `default=gnome;gtk`, preventing user-level `portals.conf` from routing Niri requests to `xdg-desktop-portal-hyprland`.
  - **XWayland Satellite Integration**: Added `pkgs.xwayland-satellite` to `modules/system/niri.nix` systemPackages so X11 applications function properly under Niri sessions.
  - **Polkit Dual-Launch Deduplication**: Removed redundant `systemd.user.services.polkit-gnome-authentication-agent-1` from `modules/system/services.nix`, letting `systemd-xdg-autostart-generator` manage the service without race collisions.
  - **Niri Config & Script Sanitization**: Updated `config.kdl` monitor mode to `2880x1620@120.002` and escaped ampersands in hotkey overlay markup. Replaced all lingering `~/.config/hypr` references in QuickShell components and helper scripts (`exit.sh`, `fix_audio.sh`, `cycle-shader.sh`).
- **Result:** Idle CPU usage normalized, Waybar and QuickShell run as singular stable processes, zero portal D-Bus timeouts, and clean Niri config validation.


## 2026-09-15 — Native TopBar (Waybar) & QuickShell Popups Suite on Niri

- **Context:** The user requested replacing QuickShell TopBar with Waybar and Lockscreen with Swaylock, styling Fuzzel with exact Rofi monochrome glass & Left/Right navigation, while keeping QuickShell's rich image-enabled Clipboard Manager (`Mod+V`) and retained popups (Monitors, FocusTime, Music, Wallpaper), fixing the Monitor widget and Matugen colors, and keeping `dotfiles/hypr/` 100% untouched.
- **Decision:**
  - Standardized on a clean hybrid architecture:
    - **Waybar**: Floating glassmorphic containers (`alpha(@surface, 0.65)`, `border-radius: 22px`, subtle dropshadow), embedded Cava visualizer, clock, battery with format-alt showing remaining discharge time on click, and reliable workspace switching (pre-declared workspaces 1-5 in `config.kdl`). Fixed GTK3 CSS transform crash.
    - **SwayNC**: Notification daemon and slide-out control center with battery telemetry, wifi, bluetooth, mute, and power profiles.
    - **Swaylock**: Native lockscreen invoked by `Shift+F2`, `Super+Alt+L`, and `swayidle`.
    - **Fuzzel**: Exact Rofi monochrome translucent glass (`rgba(0,0,0,0.45)`, `00000073`), 500px width, font 14, and Left/Right arrow key line scrolling.
    - **QuickShell Popups Suite (`dotfiles/niri/quickshell/Shell.qml`)**: Running only `Main {}` and `Floating {}` without TopBar or Lockscreen. Provides rich Clipboard Manager with decoded image thumbnails (`Mod+V`), Music Player (`Mod+Shift+M`), Volume (`Mod+Ctrl+V`), Focus Time (`Mod+Alt+F`), and Wallpaper Picker (`Mod+Shift+W`).
    - **Monitor & Matugen Niri Adapters**: Created `get_monitors.py` and `apply_monitors.py` bridging `niri msg outputs` into QuickShell without `hyprctl`. Fixed `MatugenColors.qml` watcher path.
  - Preserved `~/nix/dotfiles/hypr/` 100% untouched and clean.
- **Result:** Complete visual elegance, fast native topbar, reliable workspace clicking, rich image clipboard history, functional monitor controls, and zero Hyprland coupling.

## 2026-09-15 — Self-Contained Niri Desktop Ecosystem & Safe Hyprland Deletion

- **Context:** The user requested fully separating the Niri desktop configurations so they can edit Niri independently and delete `dotfiles/hypr/` at any time without affecting the Niri desktop environment.
- **Decision:**
  - Migrated QuickShell (`quickshell/`), settings (`settings.json`), GLSL shaders (`shaders/`), and all 27 helper scripts directly into `~/nix/dotfiles/niri/` (symlinked as `~/.config/niri/`).
  - Rewrote internal paths across all 30 scripts and QML files to reference `.config/niri/` instead of `.config/hypr/`.
  - Updated `systemd.user.services.focustime-daemon` in `home.nix` to execute from `%h/.config/niri/quickshell/focustime/focus_daemon.py`.
  - Configured `config.kdl` and `swayidle/config` to strictly trigger Niri-local scripts.
- **Result:** Niri runs as a completely independent, self-contained desktop ecosystem. The `~/nix/dotfiles/hypr/` directory remains intact as an archived baseline and can be deleted whenever the user chooses without breaking Niri.

## 2026-09-15 — Unified QuickShell Desktop Architecture across Hyprland & Niri

- **Context:** Rather than running degraded separate tools (Waybar, SwayNC, Fuzzel menus) on Niri, the user requested full aesthetic, UI widget, and keybinding parity with the primary Hyprland rice.
- **Decision:**
  - Standardized on QuickShell (`Shell.qml`, `TopBar.qml`, `Floating.qml`, `Lock.qml`, `NotifTicker.qml`) as the single authoritative desktop UI across both compositors.
  - QuickShell `TopBar.qml` connects natively to `niri msg --json event-stream` with a `SplitParser` under Niri sessions, rendering identical dynamic Japanese Kanji / numbered workspace pills (active, occupied, empty) with zero polling overhead.
  - `qs_manager.sh` detects Niri to dispatch `niri msg action focus-workspace <n>` (and `move-column-to-workspace`) for workspace pill clicks, while routing all popup toggle commands (`network`, `volume`, `focustime`, `monitors`, `battery`, `wallpaper`, `clipboard`, `music`, `calendar`) identically to QuickShell's IPC handler.
  - In `config.kdl`, killed competing notification daemons (`swaync`) at startup to ensure QuickShell claims `org.freedesktop.Notifications`, and mapped all Hyprland keybindings 1:1.
  - Upgraded `focus_daemon.py` to stream Niri window events into `focus.db`, preserving the user's canonical application names and Focus Time tracking.
- **Result:** Complete visual, operational, and keyboard parity between Niri and Hyprland without duplicate or compromised UI stacks.

## 2026-09-12 — Modular Coexistence of Niri and Hyprland Desktops

- **Context:** The user wanted to try out Niri while preserving the entire existing Hyprland rice, dotfiles, and NixOS configurations intact.
- **Decision:**
  - Placed all Niri, Waybar, SwayNC, Fuzzel, Foot, wlogout, Swaylock, Swayidle, and Kanshi configurations in completely independent subdirectories under `~/nix/dotfiles/` and separate Nix modules (`modules/system/niri.nix`, `modules/home/niri.nix`, `modules/home/fish.nix`).
  - Switched display manager to Ly (`services.displayManager.ly`) with `save = true`, allowing seamless switching between Niri and Hyprland sessions while defaulting to the user password prompt on boot.
  - Connected Niri and its companion utilities to the existing Matugen pipeline via additional template definitions, keeping dynamic wallpaper theming synchronized across both desktop environments.
- **Result:** Hyprland and Niri coexist cleanly without config collisions, package conflicts, or shared runtime instability.

## 2026-09-10 — Declarative Flatpak & GNOME Software Center Integration
- **Context:** User requested installing and using Flatpak applications through a graphical software store app under Hyprland.
- **Decision:**
  - Enabled `services.flatpak.enable = true;` in `~/nix/modules/system/services.nix`.
  - Added `systemd.services.flatpak-repo` to declaratively ensure the official Flathub remote repository is added automatically on boot.
  - Added `gnome-software` to `~/nix/modules/system/packages.nix` for visual browsing, installation, and updating of Flatpaks.
- **Result:** Graphical Flatpak installation works out of the box via "Software" with desktop icons and Rofi launch integration.

## 2026-09-10 — AppImage Direct Execution via kernel binfmt_misc
- **Context:** Standalone AppImages cannot run out-of-the-box on NixOS because they hardcode ELF dynamic linkers (`/lib64/ld-linux-x86-64.so.2`) that do not exist under NixOS's store architecture.
- **Decision:** Configured `programs.appimage = { enable = true; binfmt = true; };` in `~/nix/modules/system/packages.nix`.
- **Result:** NixOS registers `appimage-run` as the kernel binary format handler for AppImage magic bytes. Executable `.AppImage` binaries run directly without wrapper commands or repackaging.

## 2026-09-07 — Manual UI Dark/Normal Mode Toggle via CTRL+SUPER+D

- **Context:** Auto dark mode was automatically switching terminal background opacity and TopBar pill contrast on wallpaper change based on top image luminance, overriding user preference.
- **Decision:**
  - Removed automatic `is_light` overwriting in `~/nix/dotfiles/hypr/scripts/set_wallpaper.sh`.
  - Added `~/nix/dotfiles/hypr/scripts/toggle_dark_mode.sh` toggling `wallpaper_is_light.txt` and `qs_colors.json`.
  - Bound `mainMod + CTRL + D` in `keybinds.lua` to toggle UI between Normal (transparent) and Dark Contrast (frosted) mode.
- **Result:** User has full manual control over desktop UI contrast without unintended wallpaper-triggered theme flips.

## 2026-09-07 — Focus Daemon Zero-Fork In-Process Screen Lock Detection
- **Context:** Battery discharge was interrupted by periodic process wakeups. `focus_daemon.py` was calling `pgrep -x hyprlock` once per second inside its main tick loop (3,600 fork/exec calls per hour).
- **Decision:** Replaced `subprocess.check_output(['pgrep', '-x', 'hyprlock'])` with direct in-process `/proc` binary scanning (`os.scandir('/proc')`).
- **Result:** Eliminates 3,600 process spawns per hour and reduces lock check execution time from ~75ms down to ~10ms with zero subprocess overhead.

## 2026-09-07 — Smart AC Performance Profile & Intel GPU Framebuffer Compression
- **Context:** CPU on AC was locked at 4.4 GHz at 0% load due to `CPU_ENERGY_PERF_POLICY_ON_AC = "performance"`, creating high baseline heat, fan noise, and reducing thermal boost headroom for gaming. In addition, `i915.enable_fbc` was disabled, wasting ~2.2 GB/s memory bandwidth on a 2.8K 120Hz display.
- **Decision:**
  - Set `CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance"` and `RUNTIME_PM_ON_AC = "auto"` in `~/nix/modules/system/power.nix`.
  - Added `boot.kernelParams = [ "i915.enable_fbc=1" ];` to compress the 120Hz display buffer in dedicated GPU hardware cache.
- **Result:** CPU cores idle down to 400–800 MHz when idle on AC, saving thermal budget for gaming. Turbo boost (4.7 GHz) and ASUS performance platform profile remain 100% available under load.

## 2026-09-07 — Battery Power Profile & Transient Spike Elimination
- **Context:** User observed high power draw (~18W) during light work on battery. CPU was spiking to 4.7 GHz due to aggressive battery EPP and turbo settings.
- **Decision:** In `~/nix/modules/system/power.nix`, updated TLP battery profile:
  - `CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power"` (prevents aggressive ramping on minor wakeups).
  - `CPU_BOOST_ON_BAT = 0` (caps 12 cores at base frequency on battery; eliminates peak voltage spikes while keeping full multi-core throughput).
  - `CPU_HWP_DYN_BOOST_ON_BAT = 0` (disables hardware dynamic boost on battery).
  - `PLATFORM_PROFILE_ON_BAT = "quiet"` (aligns ASUS platform profile on battery).
- **Result:** Drastically reduces transient power spikes from background tasks and electron apps, allowing CPU package to settle into lower power states.

## 2026-09-07 — Quickshell inotifywait Self-Trigger Feedback Loop Prevention

- **Context:** Laptop was burning ~48 W battery on idle, fan at 4,000 RPM, CPU temp at 84°C, spawning ~3,882 processes/second.
- **Root Cause:** `MatugenColors.qml` was instantiated across 11 components (`TopBar`, `BatteryPopup`, `NetworkPopup`, `CalendarPopup`, `MusicPopup`, `Lock`, `MonitorPopup`, `FocusTimePopup`, `ClipboardManager`, `Floating`, `WallpaperPicker`). Each instance ran `colors_wait.sh`, which unconditionally ran `touch "$TARGET"` on startup. The `touch` caused `CLOSE_WRITE` to trigger across all other 10 `inotifywait` instances, which exited, triggered `onStreamFinished`, and spawned `colors_wait.sh` again, creating an infinite cross-firing fork bomb.
- **Decision:** In `dotfiles/hypr/scripts/quickshell/watchers/colors_wait.sh`, replaced `touch "$TARGET"` with `[ -f "$TARGET" ] || touch "$TARGET"`. Never touch or modify a watched file inside an inotify watcher loop if the file already exists.
- **Result:** PID spawn rate dropped from 3,882/s to 2.5/s, CPU system time dropped from 38% to 1-2%, CPU idle rose to 95%, and thermals dropped back down.

## 2026-09-07 — KDE Connect RemoteDesktop Portal Bridge & Virtual Input Permissions

- **Context:** KDE Connect on Hyprland could not operate Remote Input (mouse/typing), Presentation Remote (slide keys), or Drawing Tablet (virtual digitizer). Hyprland portals do not implement `org.freedesktop.portal.RemoteDesktop` (EIS input emulation), and `/dev/uinput` was restricted to `root:root 0600`.
- **Decision:**
  - Codified custom `hypr-kdeconnect-portal` package in `pkgs/hypr-kdeconnect-portal.nix` bridging libeis/RemoteDesktop into Hyprland virtual pointer/keyboard protocols.
  - In `xdg.portal`, added `hypr-kdeconnect-portal` to `extraPortals` and mapped `config.hyprland."org.freedesktop.impl.portal.RemoteDesktop" = [ "hypr-kdeconnect" ];`.
  - Enabled `hardware.uinput.enable = true;`, added `services.udev.packages = [ pkgs.kdePackages.kdeconnect-kde ];`, and added `"uinput"` and `"input"` to user `extraGroups`.
- **Reproducibility:** All configuration is purely declarative in the NixOS flake (`flake.nix`, `modules/system/services.nix`, `modules/system/users.nix`), ensuring zero manual configuration is required on new laptops.

## 2026-08-30 — Quickshell Workspace Model In-Place Updates & Window Lifecycle IPC

- **Context:** Workspace pills in TopBar failed to remove empty inactive workspace icons, failed to refresh when windows opened/closed/moved, and flickered during active highlight positioning.
- **Decision:**
  - `occupiedMap[ws.id]` now explicitly checks `(ws.toplevels.count > 0 || ws.lastIpcObject.windows > 0)` to guarantee empty workspaces mark as empty and hide.
  - `onRawEvent` in `Connections` now listens for window lifecycle events (`openwindow`, `closewindow`, `movewindow`, `movewindowv2`, `moveworkspacev2`) to trigger real-time workspace icon updates.
  - `workspacesModel` updates in-place via element diffing instead of `.clear()`, preserving QML Repeater delegate lifecycles and smooth active pill animations.

## 2026-08-30 — Quickshell Native Event-Driven Architecture (Zero Process Spawning)

- **Context:** Quickshell was spawning continuous bash helper processes (`workspaces.sh`, `power_state_watcher.sh`, `socat`, `update_wait.sh`, `wpctl`) and 2s timers, consuming 15.2% CPU and drawing ~28 W battery power.
- **Decision:** Replaced all periodic shell processes with native Quickshell 0.3.0 C++ D-Bus and IPC bindings:
  - Workspaces: `import Quickshell.Hyprland` (`Hyprland.focusedWorkspace`, `Hyprland.workspaces`, `Hyprland.rawEvent`) for 6ms native socket IPC.
  - Audio: `import Quickshell.Services.Pipewire` (`Pipewire.defaultAudioSink.audio`) for 8ms D-Bus volume signals.
  - Platform Profile: `Quickshell.Io.FileWatcher` reading `/sys/firmware/acpi/platform_profile` directly.
- **Power Result:** Continuous idle power draw dropped from 28.25 W down to **10.85 W**, CPU sleep residency recovered to **87.41%** (66.14% in deep C3 sleep), and CPU usage dropped to **1.7%**.

## 2026-08-30 — TLP 1.9.1 Sole Authority over ASUS Platform Profiles

- **Context:** `asusd.service` was attempting to manage platform profiles concurrently with TLP.
- **Decision:** Set `change_platform_profile_on_battery/on_ac = false` in `environment.etc."asusd/asusd.ron"`. TLP is now the sole authority for hardware power profiles. `services.asusd.enable = true` is retained strictly to enforce the 80% battery charge ceiling (`charge_control_end_threshold = 80`).

## 2026-08-30 — MPV Local Media MPRIS D-Bus Plugin Integration

- **Context:** `mpv` playing local audio/video did not emit MPRIS D-Bus signals, so `playerctl` and Quickshell music widgets could not detect local media playback.
- **Decision:** Added `mpvScripts.mpris` to `mpv` package in `modules/system/packages.nix` (`(mpv.override { scripts = [ mpvScripts.mpris ]; })`) and symlinked `mpris.so` into `~/.config/mpv/scripts/`. `mpv` now emits standard D-Bus `org.mpris.MediaPlayer2` signals on launch.

## 2026-08-24 — anifetch `af()` restored (uncommitted-code loss)

- **Context:** `af` (zsh function cycling `~/Pictures/fastfetch` gifs/mp4s
  through anifetch with auto-sized chafa output) silently vanished. Root
  cause: it existed only as uncommitted working-tree changes when its build
  happened (`git log -S anifetch --all` = zero commits); a later rebuild
  baked a `.zshrc` without it. The flake input survived (committed), but the
  function and PATH entry did not.
- **Decision:** Restored verbatim in `modules/home/shell.nix`: module args
  `{ inputs, pkgs, ... }`, `home.packages +=
  inputs.anifetch.packages.${pkgs.system}.default`, and the exact `af()`
  body from the old generation's `.zshrc`
  (`/nix/store/2fyyz23…-home-manager-files/.zshrc`), with `${` escaped as
  `''${` for the Nix indented string. Verified byte-identical via diff.
- **Rule earned:** shell functions in `initContent` are config like any
  other — if they're not committed before the rebuild that consumes them,
  they don't exist. `rebuild()`'s `git add -A` covers this; never rebuild
  with intentionally-uncommitted code you expect to keep.


## 2026-08-20 — Rofi Wayland Native Scaling Fix

- **Context:** Rofi UI was massive and disproportionate under Wayland scaling.
- **Decision:** The `rofi` package currently installed is natively Wayland. The issue was purely CSS. Changed `theme.rasi` from massive fixed sizes (e.g., `800px`, `22px` font) to scaled-down standard sizes (`14px` font). Logical pixel dimensions now correctly scale with Hyprland scaling without looking bloated.

## 2026-08-20 — Force Electron/Chromium to Native Wayland

- **Context:** Touchpad gestures (e.g., horizontal scrolling) didn't work in applications like Brave because they were running in XWayland.
- **Decision:** Added `NIXOS_OZONE_WL = "1"` system-wide in `hosts/nixos/default.nix` and `--ozone-platform-hint=wayland` in `home.nix`. All electron/chromium apps will now default to native Wayland, natively passing through touch/scroll events.

## 2026-08-20 — EasyEffects: Service Preset Exits Daemon

- **Context:** The QuickShell equalizer failed to communicate because the `easyeffects` daemon was dead.
- **Decision:** Removed `preset = "live_eq"` from `home.nix`. Starting EasyEffects with `--load-preset` causes the process to exit immediately on newer versions instead of running persistently. `equalizer.sh` already handles pushing presets securely to the live background daemon, making the service-level flag redundant.

---

## 2026-08-16 — Pin REMOVED: nixpkgs back on nixos-unstable (supersedes below)

- **Decision:** `flake.nix` nixpkgs URL restored to
  `github:NixOS/nixpkgs/nixos-unstable`. The e2587ca pin below was a
  TEMPORARY recovery measure (user preference: flexibility over pinning) and
  is removed. No kernel/Mesa/WezTerm/package pins, no forced boot generation,
  no compatibility overrides accompany this change.
- **Boot default:** the forced `default nixos-ae84e1df…conf` line
  (generation 760, e2587ca/7.1.4) was removed from
  `/boot/loader/loader.conf` (systemd 261 has no `bootctl unset-default`
  verb, so the line was removed directly; identical effect) — systemd-boot
  again boots the newest generation normally.
- **Safety unchanged:** rebuild() → build → switch → health-check.sh →
  rollback on CRITICAL stays. The 14d GC window stays (rollback target must
  survive). The first unstable rebuild re-locks nixpkgs to the newest
  nixos-unstable rev; plain rebuilds keep it; `update()` raises it on demand.

## 2026-08-16 — Kernel 7.1.8 is CO-IMPLICATED; nixpkgs pinned to e2587ca

**Supersedes part of the entry below** ("kernel bump exonerated" — proven wrong).

- **New evidence (controlled probes, same boot/GPU state, mixed stack):**
  - On kernel **7.1.8** + 07-16 userland (pre-reboot): probe hung **1× at
    15:16**, then **2× at 15:25** (ecode 12:1:859ffffb; context reset recovered;
    CLI still rc=0, window rendered).
  - On kernel **7.1.4** + 07-16 userland (post-reboot, fresh i915): **2/2
    clean probes** (health-check EXIT 0), zero GPU HANGs, terminal fully
    functional.
  - Conclusion: 7.1.8's i915 side (or its interaction) is a co-trigger of the
    hang family — never shipped in the weeks of hang-free use.
- **Decision:** `flake.nix` pins `nixpkgs.url = github:NixOS/nixpkgs/e2587ca`
  (2026-07-23; kernel 7.1.4, the running known-good). This is the sanctioned
  *diagnosed-cause* exception to "no global pins" (below). `flake.lock` was
  regenerated; the URL pin is the source of truth (lock is gitignored by user
  choice).
- **STATUS: TEMPORARY recovery measure only (user preference: flexibility
  over pinning).** Not policy, not "required for stability". The user may
  remove/update it at any time, or when a newer stack passes the health gate.
  Do NOT extend it into a permanent rule, pin boot entries, or block version
  bumps "for stability" — propose and ASK first.
- **Verified:** `kernelPackages.kernel.name` → `linux-xanmod-7.1.4` from the
  flake; generation 757 (7.1.4) is boot default; booted system = j89blis
  (e2587ca) closure.

## 2026-08-16 — Rebuild safety: build≠safe, generation is the unit of trust

- **Context:** `nixos-rebuild switch` (gen 758) introduced a userland
  regression — wezterm 0-2026-08-05 + newer mesa from nixpkgs rev `0e251e2`
  — that reproducibly i915-GPU-hangs (ecode 12:1:859f7c05/859ffffb) on
  Raptor Lake Iris Xe. Reproduced on BOTH kernels (7.1.4 old-gen boot and
  7.1.8 new-gen boot): kernel bump exonerated; the trigger is userland
  (wezterm build and/or mesa 26.2). Multiple wezterm instances froze;
  recovery required a separate editor.
- **Decision:** safe-rebuild flow (shell.nix `rebuild()`, `health-check.sh`):
  1. Record known-good BEFORE touching anything: `~/.cache/nix_rebuild_log`
     (time + gen link + git HEAD) and `git tag -f known-good`.
  2. Commit first (keeps flake build clean-tree → generation↔commit
     correlation; gen dirs store no revision).
  3. BUILD before activate (`build -o /tmp/...`; failure → abort, nothing
     activated).
4. Post-switch health gate, journal-scoped to the switch moment:
      CRITICAL = Hyprland dead, or wezterm probe (isolated
      `--always-new-process`, pid-attributed GPU-HANG count) fails.
      WARNINGS (quickshell, pipewire trio, portal) never roll back.
   5. CRITICAL → auto `switch --rollback`, verify restored gen, print failed
      gen (kept selectable/bootable), health log, investigation commands.
   - **Probe pid attribution (hard-won):** `wezterm start` spawns a
     **launcher `wezterm-gui`** (direct child of the CLI) which then spawns
     the **per-window `wezterm-gui`** (grandchild). i915 attributes GPU hangs
     to the *per-window* process, so tracking only the CLI's direct child
     (the launcher) silently misses real probe hangs. `health-check.sh`
     captures the **full descendant tree** (BFS over `ps`) and attributes any
     hang among those pids to the probe; it never touches pids outside the
     tree.
- **Rollback target lifetime:** nix.gc weekly `--delete-older-than 14d`
  (was 7d) and `clean()` = `--delete-older-than 14d` (was `-d`, which
  deleted ALL old generations — rollback target after `clean` was gone).
- **Lesson:** a successful build/switch is a hypothesis, not a guarantee.
  "new generation is bad → detect → rollback" beats
  "new generation is bad → desktop unusable → manual recovery".
- **Rejected:** global nixpkgs pins / speculative package pins (treat
  symptoms, drift, user forbids without a diagnosed cause); monitoring
  daemons for health (one script called by rebuild() is enough);
  commit-after-switch (dirty-tree builds break gen↔commit correlation,
  failed builds strand uncommitted churn).

## 2026-08-16 — SCRIPT_DIR redefinition in caching.sh breaks "simplified" paths

- **Context:** An external audit claimed `ddg_search.sh:26` pointed at a
  non-existent path and "fixed" it to `$SCRIPT_DIR/get_ddg_links.py`. The fix
  was committed and shipped.
- **Truth (verified live):** `caching.sh:10` **redefines** `SCRIPT_DIR` to the
  *scripts root* via `BASH_SOURCE[0]` when sourced (ddg_search.sh:7). The
  original `$SCRIPT_DIR/quickshell/wallpaper/get_ddg_links.py` resolved
  correctly at runtime; the "fixed" path resolved to `scripts/get_ddg_links.py`
  which does not exist → search silently dead.
- **Decision:** Reverted to the original nested path. Rule: **when a script
  sources caching.sh, paths after the source line are relative to the scripts
  root, NOT the script's own dir.** The lockscreen doc (with `bash -x`
  evidence) was right; the audit doc's claim was a static-analysis artifact.
- **Rejected approach:** trusting lint/static checks over runtime `SCRIPT_DIR`
  semantics; "simplifying" paths without checking for later `SCRIPT_DIR`
  reassignment.

## 2026-08-16 — Fresh repo, single init commit (history preserved locally)

- **Context:** Pushing from a detached HEAD failed (3 commits diverged from
  `main`'s 4 main-only commits). User chose **current disk state** over the
  pushed repo for the fresh GitHub repo.
- **Decision:** `~/nix` re-initialized (`9600ca9 init`), pushed to
  `git@github.com:Realdhiru/nix-files.git`. Old history kept in
  `~/.git-pre-fresh-upload-20260816-0300/` and
  `/tmp/opencode/nix-history.bundle` (all refs). **Backup not deleted until
  user confirms the GitHub repo is correct.**
- **Rejected:** migrating main's 4 commits (liquid-glass Lock, topbar
  brighten, palette pipeline, desktop-entries.nix) into the fresh repo.

## 2026-08-16 — flake.lock excluded from the repo

- **Context:** `~/.gitignore` has `*.lock` → flake.lock is not tracked.
- **Decision:** User's explicit choice, kept. Lockfile integrity is not part
  of repo policy; the flake still pins via inputs.

## 2026-08-16 — docs/ is local-only

- **Decision:** `docs/` gitignored, never pushed. Documentation describes
  disk state, which may exceed the pushed repo.
- **Rationale:** user preference; keeps the public repo minimal.

## 2026-08-16 — EPP writes fail (EBUSY) while governor=performance

- **Context:** intel_pstate refuses EPP >0 under the `performance` governor.
  TLP sets ON_AC governor=performance, so power-saver EPP silently failed on
  AC (the `2>/dev/null` hid the error).
- **Decision:** `set_epp.sh` sets the governor first (powersave for any
  non-performance mode), then EPP. All three profile transitions verified.

## 2026-08-16 — apply_profile.sh is the single source of truth for power profile

- **Decision:** `battery/apply_profile.sh` owns the desktop-visible profile:
  EPP+governor (`set_epp.sh`), turbo, internal-monitor RR, shader/blur/shadow
  cut. Consumers: SysData.qml picker + lid-monitor.sh.
- **Restriction:** it must NOT call `tlp ac`/`tlp bat`. The udev rule in
  `power.nix` is the sole AC/BAT authority and re-asserts TLP settings on
  plug events (overriding a manual profile pick is expected).

## 2026-08-16 — Lid policy: never suspend

- **Decision:** `HandleLidSwitch = "ignore"` (services.nix, logind) is
  permanent. Lid close = display off + power-saver profile; lid open =
  display on + restore by charger state. Owned by `lid-monitor.sh`
  (udevadm-driven, no polling). Suspend is manual only (`Shift+Esc`).
- **Rationale:** laptop-bag safety comes from the powersave switch, not sleep.

## 2026-08-17 — Lid open restores the exact pre-close profile

- **Decision:** `lid-monitor.sh` now snapshots the active profile
  (`/tmp/qs_power_profile`, the existing source of truth) to
  `~/.cache/qs_lid_prev_profile` on close, and on open restores EXACTLY that
  profile via `apply_profile.sh` (AC->performance / battery->balanced fallback
  only when no valid snapshot exists). The DPMS-off on lid close is a direct
  compositor call (`hyprctl eval hl.dispatch(hl.dsp.dpms({action='off'}))`)
  that is deliberately NOT idle-aware: Coffee Mode (`systemd-inhibit
  --what=idle`) only gates hypridle idle detection and can never block it.
  The marker's existence = "restore armed", mirroring the existing
  `qs_pre_saver_shader.conf` pattern; no power logic duplicated.
- **Also:** `hypridle.conf` DPMS commands switched to the Lua eval form
  (native `hyprctl dispatch dpms on/off` is a Lua parse error under the Lua
  engine — hypridle's idle display-off had silently broken), and the
  hyprlang migration backup moved to `~/nix/backups/hypr-hyprlang-2026-08-16/`
  (byte-identical; dead `.conf` copies removed from the live dir after SHA256
  verification against the backup).

## 2026-08-16 — 6-char hex everywhere for matugen-derived colors

- **Context:** external audit found 8-char hex (e.g. `#aabbccdd`) broke QML
  color parsing in some paths.
- **Decision:** `extract_raw_colors.sh` truncates to `:0:7` (`#RRGGBB`); all
  consumers use 6-char hex.

## 2026-08-15 — EasyEffects: real preset dir + handoff, not duplicates

- **Context:** EE 8.2.7 stores presets in `~/.local/share/easyeffects/output`,
  not `~/.config`. A second `easyeffects -l` hands off via local socket.
  `pgrep -x easyeffects` never matches Nix-wrapped `.easyeffects-wr` comm.
- **Decision:** `equalizer.sh` (a) checks liveness via
  `systemctl --user is-active easyeffects`, (b) applies presets by handing
  them to the service's running instance, (c) never spawns its own instance.
  HM `services.easyeffects` starts with `--load-preset live_eq` so the state
  survives boot.

## 2026-08-15 — workspaces.sh flock contract

- **Decision:** a spawn that loses the flock exits **code 7**; TopBar must not
  auto-respawn on 7 (respawn-loop race). The daemon exits on repeated
  socket-connect failures (stale `HYPRLAND_INSTANCE_SIGNATURE` after Hyprland
  restart would otherwise park the flock and freeze the ws bar forever).

## 2026-08-15 — Quickshell reload orphans watchers

- **Decision:** `reload.sh` must `pkill -f "quickshell/watchers"` before
  respawning the shell; orphaned `Process` watchers self-clean ≤300s.

## 2026-08-14 — Lock screen = standalone quickshell instance

- **Decision:** `lock.sh` runs Lock.qml as its own quickshell process with
  WlSessionLock. The live wallpaper (Image / AnimatedImage / MediaPlayer with
  `MultiEffect` blur) is drawn **inside** Lock.qml; no separate wallpaper
  window. qtmultimedia QML is wired via `quickshellWrapped` in packages.nix.

## 2026-08-14 — Popup roots need explicit layout size

- **Context:** popup roots as bare `Item` caused layout corruption; Quickshell
  window sizing didn't propagate to the root item.
- **Decision:** popup roots bind `layoutWidth`/`layoutHeight` to
  `width`/`height` (Floating.qml). `Repeater.model` array identity rule from
  AGENTS.md also lives here (canonical arrays, content dedupe).

## 2026-08-12 — Wallpaper login path owned by boot_wallpaper.sh

- **Context:** cold matugen+mpvpaper on login took ~27s; warm push ~0.19s.
- **Decision:** single `boot_wallpaper.sh` runs the warm path; prune keeps the
  active wallpaper's cache. `set_wallpaper.sh` remains the picker path.

## 2026-08-11 — awww daemon lifecycle owned by ensure_awww.sh

- **Decision:** `ensure_awww.sh` is the single owner (idempotent probe/start,
  teardown before mpvpaper restart, restart on monitor-layout change).
  `awww-daemon` needs `--format xrgb` for the 10-bit panel. A later audit
  commit (2a099f8…) added a "video invariant + lock PNG" bundle that was
  **reverted** (`git reset --hard e2c776d`) — see the HISTORICAL audit doc.
  The Lock.qml video branch seen today is a *separate, live* implementation.

## 2026-08-10 — Focustime daemon is a systemd user service

- **Decision:** `focustime-daemon` (Restart=always, RestartSec=3) replaces the
  Hyprland exec-once + launch_daemon.sh supervisor. Widget refuses state files
  whose date doesn't match today; daemon re-resolves the Hyprland socket on
  restarts. Stats via `get_stats.py` (off-by-one + double-count bugs fixed).

## 2026-08-10 — Coffee mode uses systemd-inhibit, not hypridle IPC

- **Context:** hypridle 0.1.7 has no runtime IPC.
- **Decision:** `idle_inhibit.sh` (SUPER CTRL I) starts
  `systemd-inhibit --what=idle sleep infinity` in a setsid session; release =
  group-kill. Idle listener 10s → dpms-off stays active; lock@120s /
  suspend@10000s commented out.

## 2026-08-09 — GTK theme: env var is the only channel

- **Context:** gsettings/settings.ini are dead system-wide (settings path
  mismatch); xdg-desktop-portal-gtk 1.15.3 has a second-display bug in
  externalwindow-wayland.c.
- **Decision:** `GTK_THEME=Adwaita:dark` via sessionVariables + environment.d.
  Do not fight the portal.

## 2026-08-08 — Liquify V2 state = localStorage, seeded not overwritten

- **Context:** Liquify V2 (Spotify) stores config in
  `~/.cache/spotify/Default/Local Storage/leveldb` (62 keys), not a JSON file.
- **Decision:** the seed extension writes only missing keys at first run;
  legit UI changes must never be clobbered.

## 2026-08-07 — ASUS brightness keys after hibernate

- **Context:** backlight keys dead after resume until udev rebind.
- **Decision:** `workarounds/asus-brightness-rebind.nix` unconditionally
  rebinds `acpi.video_bus.0` on systemd-hybrid-sleep.service (unconditional
  because resume-after-shutdown also needs it). CLOSED; see debugging doc.

## 2026-08 — Misc audio/weather/battery decisions (external audit round)

- `audio_control.sh`: `wpctl` (PipeWire) primary, pactl fallback; `*` star
  default detection via `wpctl get-default`.
- `weather.sh`: `${f_pop:-0}` awk guard against missing pop value.
- `battery_fetch.sh`: skip BAT\*/hidpp_battery/ucsi-source-psy (phantom
  batteries), read AC0; this fix is embedded in the big ws/watchers commit.
- `starship.toml` symlinked via `mkOutOfStoreSymlink` (write-through), not
  `text =` (read-only store copy).

## 2026-08 — Audit round 2 (external AI): 7 fixes accepted

- a3f8c91 wallpaper get_ddg_links path (**later shown to be a regression —
  see top entry**), 53d9c81 wpctl star, 8b5aa6a weather guard, 9c58b1d
  focustime off-by-one/double-count, 0162c98 matugen 6-char hex, 2dc1069
  starship symlink, f1c43da changelog. Its equalizer.sh claim was stale
  (already fixed 2026-08-15).

## Rejected approaches (kept for future reference)

| Idea | Why rejected |
|---|---|
| Separate wallpaper popup window for lock | Dead code (NotifPopups.qml pattern); crashes / no wl_surface.frame |
| Pin window rule for spicy-lyrics | Doesn't fix rAF race; upstream #339 unmerged |
| powerprofilesctl / power-profiles-daemon | NixOS forbids with TLP; mkForce false |
| suspend on lid close | Hard policy: never |
| `tlp ac`/`tlp bat` from profile picker | Races the udev rule |
| main branch's 4 commits into fresh repo | User chose disk state |
| Backing docs to GitHub | User wants local-only docs |
| DDG GIF-search with animated previews (2026-08-16) | Implemented, broke the picker (`AnimatedImage` has **no `loops` property** in Qt 6 — it loops indefinitely by default), then fully reverted at user request. Try buy-in on risky UI adds before shipping; never set `loops` on AnimatedImage |
