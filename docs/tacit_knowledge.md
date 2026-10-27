# System & Workflow Tacit Knowledge Reference

## 1. Taste & Aesthetic Preferences

### Visual & Interactive Controls
- **Continuous Controls Over Discrete Presets:** Strong preference for continuous, responsive sliders (e.g., Night Light / Sunset Temperature, Gamma, Saturation) rather than rigid preset buttons. Sliders must be strictly bound to valid hardware/software ranges (e.g., Gamma clamped to $\le 100\%$, never arbitrary upper limits like $125\%$).
- **Connected UI Lifecycles:** Interactive controls cannot be visual-only facades. Sliders and toggles must manage daemon lifecycles directly (e.g., launching `hyprsunset` on slider interaction if inactive, terminating it when reset to defaults).
- **Keyboard Navigation Standard:** Custom desktop widgets must support native arrow-key navigation and keyboard focus traversal alongside mouse clicks.

### Layout Geometry & Proportions
- **Zero Dead/Empty Space:** Intense dislike for unused or unbalanced space. Cards, popups, and button rows must fill available dimensions proportionally. There must be no orphan vertical voids at card bottoms or uneven lateral padding.
- **Symmetry & Balanced Padding:** UI cards must look intentionally designed rather than like an unstyled checklist. Button columns, slider rails, and headers must maintain consistent alignment, relative widths, and unified visual rhythm.
- **Content-Derived Minimum Dimensions:** Widget geometry must be derived from non-negotiable text content rather than arbitrary fixed widths. In `TopBar.qml`, the music widget column width is anchored to `timeText.implicitWidth` minimum bounds so short song titles (e.g., `命盤`) never shrink the container or truncate timeline timestamps (`01:24 / 06:45`), while long titles marquee scroll inside the allocated space.

### Color Philosophy & Theming
- **Dynamic Wallpaper Derivation:** Hardcoded color values (hex or static color names) are strictly forbidden across UI widgets, terminals, and scripts. All colors must be dynamically extracted from the active wallpaper via Wallust.
- **Purge of Residual Defaults:** Leftover palette fallbacks (e.g., hardcoded Catppuccin sapphire, blue, peach, or maroon accents in `MusicPopup`, `NetworkPopup`, `BatteryPopup`, `CalendarPopup`, `FocusTimePopup`) are considered defects. Every accent, highlight, and surface must bind to dynamic tokens.
- **OLED Pitch-Black Authority:** The physical display is an ASUS 2.8K 120Hz OLED. True black means physical `#000000` (0.000 nits, 0 mA draw). Hyprland’s compositor root background is locked to `0x000000` (disabling Hyprland's default `0x111111` gray). When wallpaper processes are killed, the screen must drop to pure `#000000`.
- **Permanent Dark Mode Rule:** The global theme is permanently locked to dark mode (`saliencedark16`). Wallpaper switches must never trigger automatic light mode. Light mode is strictly manual via `settings.json` (`"themeMode": "light"`).
- **Deterministic Neutral Mode (`--neutral`):** On pitch-black or minimalist wallpapers, extraction algorithms generate false olive-green or muddy hue spikes from compression noise. The theme engine must execute a deterministic neutral bypass (`--neutral`) to generate an OLED black-and-ivory palette without color noise.
- **Terminal Legibility via Lch Extraction:** Terminal background must remain transparent while ANSI slots (`color0`–`color15`) are derived dynamically via `ansidark16` and `lchansi`. Standard ANSI semantic roles (red for errors, green for success) must remain distinct and readable against transparent backgrounds.
- **Visualizer Styling:** TopBar CAVA visualizer requires a vertical top-to-bottom gradient reflecting wallpaper accent tones, matching the status bar styling.

### Borders, Shadows & Glassmorphism
- **Frameless / Zero-Border Standard:** Artificial hairline borders, stroke wrappers, and rotating animated masks are banned across all QuickShell widgets (`borderWidth = 0`, `borderOpacity = 0.0` in `settings.json`). Adding unrequested borders or outlines is an immediate point of contention.
- **Hardware Kawase Blur:** Blur is enforced at the compositor level on QuickShell card surfaces via `rules.lua` matching namespaces `^(quickshell|qs-master|qs-notif-toast)$` with `ignore_alpha = 0.05`. Full-screen transparent overlay surfaces (`qs-floating-overlay`) must be excluded from blur rules to prevent unnecessary GPU blur overhead.
- **Anti-Bleed Layering:** Glass surfaces must prevent high-contrast wallpaper elements (sketches, linework, text) from showing through translucent cards. Popups must use a solid foundation layer (`root.base + effectivePopupOpacity`) behind translucent components to maintain contrast and legibility.

### Naming & Structural Conventions
- **Dynamic Semantic Tokens in QML:** Use dynamic tokens (`root.primary`, `root.base`, `Theme.colors.primary`) instead of legacy `mocha.*` names or literal color strings.
- **Centralized Settings Authority:** Visual and behavioral parameters across QuickShell must be defined in `settings.json` and documented in [`docs/quickshell-settings.md`](quickshell-settings.md). Individual widget files must never hardcode localized styling or opacity overrides.
### Notifications & Widget Architecture Preferences
- **Ultra-Minimal Notification Format:** System notifications (`notify-send`) must NEVER emit conversational sentences, explanatory bodies, or descriptive prose. Text must be 1–3 words max (e.g., `"Coffee ON"`, `"Game Mode OFF"`, `"Broadcast ON"`, `"AC Connected"`), with NO secondary body text unless delivering strictly essential dynamic telemetry (e.g. connection SSID or IP).
- **Mandatory Sender Application Flag (`-a`):** Every `notify-send` call across all scripts must explicitly specify `-a "<Category/App>"` (e.g. `-a "Power"`, `-a "Audio"`, `-a "Display"`, `-a "Night Light"`, `-a "KDE Connect"`, `-a "Clipboard"`). Bare `notify-send` without `-a` causes libnotify to report `"notify-send"` or `"bash"` as sender.
- **Battery Widget Minimalism:** The battery popup (`BatteryPopup.qml`) must remain clean and uncluttered: no notification history list, and no top-row utility pills (tray box, battery left pill, DND button). The remaining runtime telemetry (`Xh Ym LEFT / FULL`) is integrated directly inside the central circular battery ring below the percentage. Card width is strictly locked to 480px.
- **Dynamic Island Sidebar Notifications:** When in Sidebar mode, notifications display via a top-centered morphing pill Dynamic Island (`NotifToast.qml`) with `Config.toastOpacity` floor (`0.70`) to preserve WCAG AA contrast over bright wallpapers while avoiding floating windows or stacking cards.
- **SideBar Notification Architecture:** QuickShell is the sole notification server (`NotifTicker.qml`). In SideBar mode (`Config.topBarPosition === "left"`), notifications float outside the bar as an elegant top-right QuickShell toast window (`NotifToast.qml`) without requiring external notification daemons (Mako/Dunst).
- **KDE Connect Lifecycle Authority:** KDE Connect must be manually toggled on-demand via `kdeconnect_toggle.sh` (`Super + Shift + K`) rather than running indefinitely in the background. On battery, idle `kdeconnectd` prevents Wi-Fi and CPU deep C-states ($C8/C10$) due to periodic LAN broadcast packet handling, while consuming ~80MB RAM. The SNI system tray icon is provided by `kdeconnect-indicator`, which automatically connects to the daemon and surfaces device battery, ping, and transfer menus in QuickShell's tray.
- **Hyprland-Lua DPMS Dispatcher Syntax:**
  - Raw `hyprctl dispatch dpms off` fails under Hyprland-Lua (`error: ')' expected near 'off'`) because `hyprctl dispatch` in lua shorthand requires Lua table/function argument syntax.
  - The deterministic way to control DPMS from scripts and CLI is `hyprctl eval "hl.dispatch(hl.dsp.dpms({action='off'}))"`.
- **Overnight Agent Workflows & Power Button Display Toggle:**
  - When running background AI coding agents overnight, Coffee mode (`SUPER + CTRL + U`) prevents automated 30-minute system sleep (`systemctl suspend`), but also blocks hypridle's 120s automated DPMS screen shutoff.
  - Press the **Power Button** (`XF86PowerOff`) to toggle the display power state cleanly via `power.sh display toggle` ($0\text{W}$ OLED draw).
  - **Critical Invariant:** `misc.key_press_enables_dpms = true` and `misc.mouse_move_enables_dpms = true` must ALWAYS remain enabled in `misc.lua`. If disabled, manual DPMS off while hypridle is inhibited traps the user in a black screen because Hyprland ignores key/mouse inputs by default and cannot wake the display.
  - In `services.nix`, `services.logind.settings.Login.HandlePowerKey = "ignore"` ensures logind yields the power key to Hyprland's `XF86PowerOff` dispatcher rather than triggering lockscreen.
- **Hyprland Lua Monitor Mirroring & Reset Semantics:**
  - `hl.get_monitors()` returns only active, non-mirrored outputs. Outputs configured as mirrors (`mirror = "<src>"`) drop from the active monitor list and return `nil` via `hl.get_monitor(name)`.
  - To un-mirror an output in Lua without disabling/recreating it, pass `mirror = ""` in `hl.monitor({ output = name, mirror = "" })`.
  - Disabling an output requires `hl.monitor({ output = name, disabled = true })`; passing `mode = "disable"` errors out in the Lua binding (`hl.monitor: error applying field 'mode'`).
- **awww Wallpaper Query Protocol:**
  - `awww query --json` outputs structured JSON (`{ "": [ { "name": ..., "displaying": { "image": ... } } ] }`).
  - Text scraping of `awww query` output is banned; parse with `JSON.parse` in QML or `jq` in shell.
- **Wallpaper Atomic State & Process Replacement Trap in `cmd_kill`:**
  - Replacing `exec "$BACKEND/set.sh"` with direct execution in `cmd_kill` toggle-on is mandatory: `exec` replaces the running shell process, truncating trailing status cleanup (`state_ctl set modes.wallpaperKilled false`, `notify-send "ON"`).
  - State files (`current_wallpaper.txt`, `last_wallpaper.txt`) must always be written via hidden tmp + rename in `$XDG_STATE_HOME/quickshell/wallpaper/` to prevent zero-byte corruption.
  - The `[ -s "$CURRENT_TXT" ]` guard ensures an empty or zero-byte file is never written to `last_wallpaper.txt`.
- **FileView Inode Drop on Atomic Rename:**
  - Inotify watches on file paths (`FileView { watchChanges: true }`) track the filesystem inode. An atomic `mv -f tmp target` creates a new inode, leaving `FileView` watching the dead unlinked inode. Watching the parent directory via `FolderListModel` detects the directory change (`IN_MOVED_TO`), allowing instantaneous `reload()` without polling.

---

## 2. Rejected Approaches & Why

### Tool & Subsystem Migrations
- **Matugen $\rightarrow$ Wallust:**
  - *Why Matugen was rejected:* Matugen (Material You algorithm) generates a tonal palette from a single dominant seed color. It failed to extract the diverse 16 ANSI colors present across complex wallpapers (neon, nature, anime), resulting in flat, repetitive, and muddy terminal schemes. It also leaked light-mode colors and produced false green spikes on dark backgrounds. Additionally, Matugen was tangled in a monolithic 220+ line `set_wallpaper.sh` script mixing daemon management with color generation.
  - *Why Wallust was chosen:* Native Rust binary using K-Means clustering in Lch colorspace (`lchansi` + `ansidark16`). Extracts distinct wallpaper colors mapped to standard terminal ANSI slots with contrast checks, and runs as an independent CLI engine emitting to `~/.cache/theme/`.
  - *Crucial Migration Lesson:* An earlier migration attempt broke the desktop because Wallust provides only 19 fixed slots (`color0`–`color15`, `bg`, `fg`, `cursor`), whereas the QML widgets depended on ~26 named Catppuccin roles from `MatugenColors.qml`. Any theming transition must preserve a semantic compatibility mapping layer (`Theme.qml`) to avoid breaking the shell.
- **Niri $\rightarrow$ Retained Hyprland:**
  - Tested running Niri (scrollable tiling compositor) as an alternative to Hyprland.
  - *Why rejected:* Incomplete keybinding parity, broken QuickShell layer surface protocols, lack of smooth touchpad gesture parity across native apps, and unnecessary configuration fragmentation. Reverted to Hyprland.
- **Rofi $\rightarrow$ Fuzzel:**
  - *Why Rofi was rejected:* Bloated configuration, poor scaling across HiDPI changes, and sluggish startup.
  - *Why Fuzzel was chosen:* Wayland-native, lightweight, instant startup, pixel-perfect frosted glass transparency, and reliable exact-string matching.
- **Flatpak & Containers (Distrobox) $\rightarrow$ Standalone Flakes & Native Packaging:**
  - *Why Flatpak and Distrobox were rejected/purged:* Flatpak introduced background daemons and service sprawl. Distrobox/Podman caused container resource exhaustion, filesystem corruption, and desktop entry collisions.
  - *Why Flakes were chosen:* True declarative immutability, zero background runtime overhead, deterministic inputs, and atomic system generation rollbacks.
- **Periodic Bash Polling Loops in QML $\rightarrow$ Native C++ IPC:**
  - *Rejected:* Running periodic `Process` or `Timer` bash scripts (`workspaces.sh`, `colors_wait.sh`, `settings_wait.sh`, `update_wait.sh`, `wpctl`) inside QML.
  - *Why:* Caused fork storms (thousands of subprocesses per hour), CPU wakeups, and high battery draw.
  - *Enforced:* Native C++ event-driven IPC only (`Quickshell.Hyprland`, `Pipewire`, `FileWatcher`, `FileView`).

### Rejected Agent Proposals & Past Corrections
- **Hallucinated DSL Fields (`no_border` / `no_shadow`):** An agent once added `no_border = true` to `hl.window_rule` in `rules.lua` without checking `hl.lua` schema, breaking Hyprland configuration reloads. Global border size was already 0 in `appearance.lua`. Never add unverified parameters to DSL wrappers.
- **Premature Fixes Without Root-Cause Diagnosis:** Agents previously jumped into editing power scripts (`setPowerProfile.sh`, TLP) before presenting empirical evidence on what was actually causing performance issues (e.g., confusing thermal throttling with inverted EPP logic). The user requires root-cause isolation with command output before code is touched.
- **Automatic Wallpaper Pausing in Power Profiles:** An agent proposed pausing video wallpapers automatically in battery saver mode. Rejected because the user maintains manual keybind control over wallpaper processes and does not want automated profile interference.
- **AI-Generated Nix Configuration Bloat:** The user conducted extensive refactoring to strip unneeded AI bloat, deleting `memory.nix` (folding zram into `boot.nix`), removing unneeded packages (`nodejs`, `vscodium`, `zbar`, `wine`), and banning speculative helper daemons.

---

## 3. Workflow Expectations of an Agent

### Verification & Testing Discipline
- **Exit Code 0 is Not Proof of Completion:** Never declare a task complete merely because a QML file compiled or `quickshell ipc call main reloadTheme` returned exit code 0.
- **Hyprland Bezier Name Trap (generated motion.lua):** Hyprland only reports undefined bezier references at runtime (error banner), not at reload exit-code level. When editing `lib/motion-gen.nix` token→bezier mappings, always regenerate `motion.lua` and confirm with `hyprctl animations` that every overridden leaf shows `bezier: <mapped-name>` matching a `bezier:` block actually emitted. Bug fix 2026-10-26: `windowsOut`/`layersOut` referenced a nonexistent `"exit"` curve (`exit_curve` is the real one).
- **Visual Layout & Proportion Audit:** Before marking UI work done, verify content proportions, check that containers fill available space without voids, ensure buttons are symmetrical, and verify anti-bleed layering against high-contrast backgrounds.
- **The Cold-Start Verification Gate:** Widgets frequently appear fine on repeated opens because geometry is cached in memory. You must test the **FIRST open** immediately following a fresh `forceReload` or compositor restart. Cold-start reveals shape snaps, container resizing jumps, and uninitialized geometry.
- **Empirical System Measurement:** When modifying power, audio, or hardware configs, verify actual runtime state (e.g., `tlp-stat -p`, sysfs register reads, PipeWire node states), not just that a script completed cleanly.

### Reporting & Interaction Style
- **Evidence-Based Reporting:** Present concrete before-and-after evidence: configuration diffs, generated file contents (e.g., `wezterm-colors.lua`), sysfs values, or command outputs.
- **Strict Separation of Diagnosis from Fix Application:**
  1. Investigate read-only first.
  2. Present the diagnostic findings and root cause with proof.
  3. Propose the exact change.
  4. Apply the change only after validation.
- **Zero Unsolicited Scope Creep:** Do not modify unrelated files, adjust global keybindings, or introduce new decorative styling (borders, animations) unless explicitly requested.
- **Verify Schema and Precedent First:** Before using helper functions or configuration tables (e.g., `hl.window_rule`, `hl.exec_cmd`), grep the codebase for existing usages or read the underlying implementation (e.g., `hl.lua`). Never assume a field exists based on generic upstream documentation.
- **Communication Density ("Caveman Mode"):**
  - Zero filler, pleasantries, or generic conversational padding.
  - High semantic density, technical rigor, and concise bullet points.
  - Clickable markdown links with absolute paths (`file:///home/realdhiru/...`) and exact line numbers.
- **Manual Git Control:** Never execute `git add`, `git commit`, or `git push` automatically. The user stages, commits, and pushes all repository changes manually.

---

## 4. Architectural Decisions & Reasoning

### Hardware Authority & Power Management
- **Single Hardware Authority (TLP 1.9.1):** TLP is the sole manager of platform profiles, EPP, and ASPM (`power.nix`). In `asusd.ron`, `change_platform_profile_on_battery/on_ac` is locked to `false`. `asusd.service` exists solely to enforce the 80% battery charging ceiling (`charge_control_end_threshold = 80`).
- **Lid Switch & Lock Behavior:** `HandleLidSwitch = "ignore"` in `logind.conf`. Closing the laptop lid never suspends the machine; suspend is strictly manual (`Shift + Esc`). All locking is unified around a single [`hyprlock.conf`](file:///home/realdhiru/nix/dotfiles/hypr/hyprlock.conf) using single-pass wide kernel blur (`blur_passes = 1, blur_size = 10`), black fallback baseline, and fluid interactive typing dot animations (`inputFieldDots`). On lid open, `power.sh lid open` triggers instant Hyprland DPMS `on` and relative `ydotool mousemove` to wake Intel OLED DRM Panel Self-Refresh (PSR) without blocking on TLP. Intermediate 1-line wrapper scripts (`lock.sh`, `suspend.sh`, `lid-monitor.sh`, `idle_inhibit.sh`) have been completely purged in favor of direct `power.sh` CLI invocations.
- **Balanced Profile Integrity:** The Balanced battery profile (`balance_performance`, Turbo `1`, Platform Profile `balanced`, ASPM `powersupersave`) is empirically calibrated and locked against arbitrary changes.
- **Intel P-State EPP Quirk:** Writes to `/sys/devices/system/cpu/cpu*/power/energy_perf_bias` fail with `EBUSY` if the scaling governor is set to `performance`. `set_epp.sh` must switch governor to `powersave` immediately prior to applying EPP values.

### Declarative Symlinks & System Modularity
- **Out-of-Store Symlinks (`mkOutOfStoreSymlink`):** Configuration files in `dotfiles/` are linked out-of-store directly into `~/.config/`. This permits instant live edits and hot-reloads without running a full `nixos-rebuild` cycle for every script, QML widget, or styling token change.
- **Subsystem Decoupling:** Strict architectural boundaries exist between modules:
  - `dotfiles/wallust/`: Standalone color engine. Handles palette extraction, luminance calculations, and template generation. Zero UI dependencies.
  - `dotfiles/wallpaper/`: Background manager (`wallpaper.sh`). Manages daemons (`awww`, `mpvpaper`), directory watching, and thumbnail caching. Hands off to the color engine via an asynchronous call (`$THEME_ENGINE "$WALLPAPER" &`).
  - `dotfiles/hypr/scripts/quickshell/`: UI layer. Reads generated colors from `~/.cache/theme/colors.json` via native IPC and reloads on frame 0.
- **Notification & Battery Widget Layout Preference:** The user strictly prefers a minimal, focused Battery Widget: zero notification panel/history, zero tray icons, zero DND toggles, and zero detached pills. Battery time remaining (`Xh Ym LEFT / FULL`) is integrated directly inside the battery ring.
- **Single-Pass Popup Scaler:** Popup `Scaler` components must bind `currentWidth: Screen.width`. Passing device-pixel bounds (`Config.masterWidth`) causes double-scaling multiplication ($1.33 \times 1.33 = 1.77$), clipping content off-screen on HiDPI displays.
- **Declarative Browser & MIME Authority:** Web protocols (`http`, `https`, `text/html`) remain permanently locked to `brave-browser.desktop` in `home.nix`. Desktop entries cannot hijack default system associations.
- **Single-Radio Wi-Fi Hardware Constraint:** The Wi-Fi adapter has a single frequency synthesizer (`#channels <= 1`). It cannot maintain a simultaneous Wi-Fi station connection and Wi-Fi hotspot on 5 GHz DFS networks without connection drops. The hotspot setup is architected to share Ethernet/USB tethering over Wi-Fi.
- **Simultaneous Audio Graph Latency Disparity:** Bluetooth A2DP audio sinks (AAC/SBC) report hardware buffer latencies of 200–340ms (`pw-cli enum-params <id> Latency maxNs`), whereas wired analog/USB DACs run at <1ms. Direct fan-out across both results in audible echo/delay. Multi-output mode resolves this by spawning a zero-CPU transient `pw-loopback` delay service (`pw-wired-delay`) set specifically to the Bluetooth sink's reported buffer duration to keep both streams in phase.

### Resolved & Completed Threads
- **Wallpaper Picker Multi-Level Sorting:** Completed. Reorganized the wallpaper picker widget to display GIFs first (sorted by dominant aesthetic color), static images second (sorted by dominant aesthetic color), and video wallpapers last (`getFileTypeRank` + HSL score band map).
- **Sunset / Night Light Widget Redesign:** Completed. UI layout overhauled to eliminate dead space, continuous slider controls, clamped gamma $\le 100\%$, and integrated daemon lifecycle control (`hyprsunset`).
- **Instant GPU Lockscreen Migration:** Completed. Migrated lockscreen to `hyprlock` with dynamic screenshot blur (`path = screenshot`, `blur_passes = 2`) and sub-20ms PAM authentication. Replaced heavy cold-start `Lock.qml` and eliminated video lockscreen overhead entirely.
- **Spotify Lyrics Floating Window Rule:** Applied in [`dotfiles/hypr/rules.lua`](file:///home/realdhiru/nix/dotfiles/hypr/rules.lua) matching class `^(chromium-browser)$` and title `.*•.*` with `float = true`, `pin = true`, `size = {300, 95}`, and `opacity = "1.0 override 1.0 override"`, properly scoped from general chromium 0.85 opacity.

### In-Progress & Unresolved Threads
- None currently open.

---

## 5. Recurring Pain Points (Proactive Watchlist)

- **QuickShell Cold-Start Geometry Snaps:**
  - *Symptom:* Widgets appear properly proportioned on second or third open, but exhibit container clipping, uninitialized bounds, or shape snaps on the very first open after a reload.
  - *Mitigation:* Always verify frame-0 geometry, ensure explicit width/height bindings on root cards, and use two-phase layer dismissal (keeping `visible = true` while exit transitions run, setting `visible = false` only when opacity reaches 0).
- **Opacity Bleed Across Translucent Glass:**
  - *Symptom:* High-contrast wallpaper linework, sketches, or text bleed through semi-transparent cards, making UI text unreadable.
  - *Mitigation:* Ensure popup containers utilize a solid base background (`root.base + effectivePopupOpacity`) backed by hardware Kawase blur (`ignore_alpha = 0.05`).
- **Ghost Workspaces in TopBar:**
  - *Symptom:* TopBar continues to render empty workspace pills after windows are closed or moved rapidly across workspaces.
  - *Mitigation:* Cached JSON workspace state settles slower than QuickShell's C++ ObjectModel. Rely on live `Hyprland.toplevels` and `ws.toplevels.count` evaluated via `Qt.callLater`, dynamically tracking `Math.max(6, focusedId, maxOccupiedId)`.
- **False Palette Spikes on Dark/Monochrome Wallpapers:**
  - *Symptom:* Setting a pure black, minimalist, or dark wallpaper causes color extraction tools to amplify compression artifacts, resulting in harsh olive-green or bright blue accent spikes across the desktop.
  - *Mitigation:* Route dark/black wallpapers through Wallust's deterministic neutral bypass (`--neutral`) and ensure fallback paths do not revert to hardcoded Catppuccin defaults.
- **CPU Wakeups from Subprocess Fork Storms:**
  - *Symptom:* Idle laptop power consumption spikes from ~6W to 14–18W due to background monitoring loops.
  - *Mitigation:* Never invoke shell utilities (`pgrep`, `hyprctl`, `cat /sys/...`, `wpctl`) inside periodic timers. Use native D-Bus bindings, Hyprland event sockets, or `FileWatcher` sysfs monitors.
- **Intel CPU EPP Writes Refused (`EBUSY`):**
  - *Symptom:* Direct writes to `/sys/devices/system/cpu/cpu*/power/energy_perf_bias` fail silently or return `Device or resource busy`.
  - *Mitigation:* Always set the CPU scaling governor to `powersave` before writing EPP register values.
- **Inode Invalidation Breaking Inotify File Watchers:**
  - *Symptom:* Background watchers (`colors_wait.sh`, QuickShell `FileWatcher`) stop responding to file changes after an update script runs.
  - *Mitigation:* Updating files via `mv -f tmp target` creates a new inode, breaking existing inotify watches. Writes must update existing inodes directly (e.g., `cat tmp > target`) or trigger explicit IPC signals (`quickshell ipc call main reloadTheme`).
- **Intel Thunderbolt 4 / Type-C Controller D3cold Resume Drops:**
  - *Symptom:* Type-C port disconnects, external drives/hubs fail to mount or drop after idle, and kernel dmesg emits `xhci_hcd: xHC error in resume, USBSTS 0x401`.
  - *Mitigation:* Denylist the Thunderbolt 4 root controllers (`00:0d.0 00:0d.3`) in `services.tlp.settings.RUNTIME_PM_DENYLIST` to prevent power cycling into D3cold while on battery. Never install artificial UCSI udev rules that force `tlp bat` upon plugging in unpowered Type-C devices.
- **Workspace Switch Lag & Highlight Coordinate Fighting:**
  - *Symptom:* Switching workspaces causes noticeable UI stutter, jittery or jumping active highlights, and erratic viewport scrolling in bar workspace widgets.
  - *Mitigation:* Rapid Hyprland events (`workspace`, `focusedmon`, `openwindow`, `workspaces.valuesChanged`) emit in tight bursts. Synchronous model recomputation on every event starves the Qt event loop. Debounce incoming events via a 16ms single-shot timer (`wsDebounceTimer`), while updating `activeIndex` immediately. Furthermore, never bind layout container offsets (`wsLayout.y`) to tweening `implicitHeight` bounds while delegates animate size (0 $\leftrightarrow$ 32px), as container motion fights the highlight animation. Explicitly offset Flickable auto-scroll targets (`wsLayout.y + activeItem.y`).
- **Wallpaper Carousel vs Keybind Traversal Sort Divergence:**
  - *Symptom:* Cycling wallpapers via `cycle_wallpaper.sh` (Super+Alt+Left/Right) applies a wallpaper that does not match the adjacent neighbor in `WallpaperPicker.qml`.
  - *Mitigation:* `cycle_wallpaper.sh` uses `jq sort_by()` with floating color keys. If `WallpaperPicker.qml` introduces deadbands (e.g. `Math.abs(aKey - bKey) > 0.5`), items with close hues invert order relative to backend cycle caches. Compare keys directly (`aScore.key !== bScore.key`) to maintain strict 1:1 order parity. Also, clicking an already active wallpaper is guarded to avoid useless re-renders; provide a transient `statusToast` instead of silently dropping the event.
- **WirePlumber Bluetooth Headset Auto-Switch & AVDTP Teardown Collisions:**
  - *Symptom:* Bluetooth earbuds (e.g. OnePlus Nord Buds 3) connect successfully at the Bluetooth/L2CAP level and report battery status, but emit zero audio. `wpctl status` shows no sink for the device or marks `bluez5.profile = "off"`. Logs show `btd_service_connect() a2dp-sink profile connect failed: Device or resource busy`, `avdtp cancel_request() Connection timed out (110)`, and `spa.bluez5: Failure in Bluetooth audio transport`.
  - *Root Cause:* WirePlumber 0.5 enables `bluetooth.autoswitch-to-headset-profile = true` by default, creating a virtual loopback recording source (`bluez_input.*`). When any application (browsers, Discord, portal) probes an audio source, WirePlumber attempts to dynamically swap the Bluetooth profile from high-fidelity A2DP (AAC) to low-quality HSP/HFP (mono mSBC/CVSD). Consumer TWS earbuds firmware crashes during live AVDTP stream teardown under concurrent audio streams, causing BlueZ to return `EBUSY`/timeout. WirePlumber fails to restore A2DP, disables the card (`profile = "off"`), and persists the broken profile in `~/.local/state/wireplumber/default-profile`.
  - *Mitigation:* Explicitly set `bluetooth.autoswitch-to-headset-profile = false` in `wireplumber.settings` in `home.nix` (`51-device-autoswitch.conf`). The laptop's internal stereo microphone handles voice input with superior clarity without risking Bluetooth transport tearing. Elevate external sinks to priority `2150` and the 10-band equalizer filter chain to `2200` so connected external endpoints never bypass the equalizer while always capturing primary output automatically.
- **PipeWire Equalizer Filter-Chain vs Physical Sink Priority Inversion:**
  - *Symptom:* Connecting Bluetooth earbuds or USB DAC/headphones causes audio applications to bypass the 10-band equalizer filter-chain entirely, playing raw uncalibrated audio directly to the physical endpoint.
  - *Root Cause:* If physical external endpoints have `priority.session = 2150` and the virtual equalizer sink (`effect_input.eq10`) sits at `2100`, WirePlumber's `linking.follow-default-target = true` marks the external physical sink as the global default sink, bypassing `effect_input.eq10`.
  - *Mitigation:* In [`home.nix`](file:///home/realdhiru/nix/home.nix), configure `effect_input.eq10` at `priority.driver = 2200` and `priority.session = 2200`, physical external devices at `2150`, and internal speakers at `1000`. The equalizer remains the uncontested default sink for apps, and its passive output (`effect_output.eq10`) forwards audio into the highest-priority physical endpoint automatically.
- **Dual ALSA Microphones (`Mic1` vs `Mic2`) & Native WebRTC Denoising:**
  - *Symptom:* `pwvucontrol` shows two internal laptop microphones (`Mic1` and `Mic2`). `Mic1` is muted and emits silence; selecting `Mic2` produces audible background hiss, room resonance, and acoustic speaker bleed.
  - *Root Cause:* ASUS Vivobook ALSA UCM configuration splits the Intel SOF DSP into raw uncalibrated PDM digital microphone pins (`Mic1`) and a calibrated stereo microphone array (`HiFi__Mic2__source`). Unprocessed `Mic2` lacks acoustic echo cancellation (AEC) and background noise suppression (NS).
  - *Mitigation:* Deploy `libpipewire-module-echo-cancel` with `monitor.mode = true` in `pipewire.conf.d/60-echo-cancel.conf`. Pin `capture.props.target.object = "...HiFi__Mic2__source"` so the WebRTC engine exclusively binds to the real microphone array, and subscribe its playback monitor to `effect_input.eq10:monitor` to subtract speaker output in real-time. Expose `echo_cancel_source` at priority `2100` as the clean default microphone.
- **FHS User Environment Sandbox Process Lifecycle (`dieWithParent = true` Trap):**
  - *Symptom:* Opening a file (e.g. `.pptx`, `.docx`) from a GUI file manager (`pcmanfm-qt`) launches the application (`onlyoffice-desktopeditors`, `lutris`, `bottles`, `chatgpt`) properly, but closing the file manager window (`Super + Q` or window close) immediately kills the opened document/app.
  - *Root Cause:* Nixpkgs wraps binary software in FHS user environments via `buildFHSEnv` / `buildFHSEnvChroot` backed by Bubblewrap (`bwrap`). The default argument in `pkgs/build-support/build-fhsenv-bubblewrap/default.nix` is `dieWithParent ? true`, which adds `--die-with-parent` to the `bwrap` command line. This registers a kernel death signal (`prctl(PR_SET_PDEATHSIG, SIGKILL)`). Because file managers fork and directly `exec` handler binaries without an intermediate daemon or systemd scope, closing the file manager causes the kernel to immediately terminate the bubblewrap sandbox and its child processes.
  - *Mitigation:* In Nixpkgs overlays ([`flake.nix`](file:///home/realdhiru/nix/flake.nix)), wrap `buildFHSEnv` and `buildFHSEnvChroot` globally using `patchFHS` to enforce `dieWithParent = false` across all installed packages. This strips `--die-with-parent` from every wrapper script across the entire system, enabling all applications to detach and reparent cleanly to `systemd --user`.
- **Qt Quick `QQuickRepeater::stackBefore` Null Dereference & Preloaded `Shortcut` Leakage:**
  - *Symptom:* Quickshell abruptly crashes with `SIGSEGV` (signal 11) in `QQuickItem::stackBefore` / `QQuickRepeater::modelUpdated` when pressing `Tab` or navigating popups.
  - *Root Cause 1 (Global Shortcut Leakage in Preloaded Windows):* Popups preloaded in background/hidden state (`visible: false`) instantiate all top-level QML elements including `Shortcut`. In Qt Quick, a `Shortcut` without an explicit `enabled: window.visible` condition remains globally active in the Qt Application event loop. Any desktop keystroke (e.g. `Tab`) gets intercepted by the hidden window's shortcut handler.
  - *Root Cause 2 (Repeater `clear()` + Synchronous `append()` Collision):* In `NetworkPopup.qml`, changing modes executed `orbitListModel.clear()` immediately followed by `syncModel(orbitListModel, dataArray)` which called `listModel.append()`. Calling `clear()` queues delegate item destruction (`destroyObjectLater`). Synchronously appending new items in the same event loop tick forces `QQuickRepeater::initItem()` to call `item->stackBefore(after)`, accessing delegates in the middle of being torn down and indexing invalid sibling pointers (`childItems.lastIndexOf`), triggering null pointer dereference.
- **HiDPI Monitor Scaling Popup Coordinate Inversion & PWA Download Bubbles:**
  - *Symptom:* Context menus, dropdowns, or download popups clip off the screen edge, spawn detached, or render with negative coordinates (e.g. appearing off-screen on the left).
  - *Root Cause 1 (Toolkit Coordinate Scale Desync):* On HiDPI displays with integer scale (e.g. `scale = 2` on 2880×1620), GTK and Qt apps lack explicit toolkit scale hints, causing them to negotiate `xdg_positioner` geometry against raw unscaled physical coordinates.
  - *Root Cause 2 (Chromium PWA Download Bubble Wayland Bug):* In Chromium/Brave PWAs (`--app=...`), the download bubble sits inside a customized client-side decoration header. The Ozone Wayland backend calculates anchor coordinates with a negative offset (`x < 0`) relative to the window origin, projecting the detached subsurface out of screen bounds.
- **ONLYOFFICE XWayland CEF Custom Titlebar UI Dropping:**
  - *Symptom:* In ONLYOFFICE (`class = ONLYOFFICE`), the document canvas and ribbon disappear, render transparent/blank, or flicker black when resized or tiled.
  - *Root Cause:* Under XWayland, ONLYOFFICE's custom CEF titlebar fails to propagate damaged surface rects during tiling adjustments when subjected to translucent compositor composition or CSD recalculations.
- **XWayland & Modal Confirmation Dialogs Defaulting to (0, 0) / Screen Edges:**
  - *Symptom:* Modal dialogs ("Are you sure?", "More than one document is open", file prompts) spawn in the upper-left corner under the side/top bar or clip off-screen.
  - *Root Cause:* Under XWayland, transient dialogs lack relative parent surface anchoring metadata unless explicit window rules enforce centering. When Hyprland's window placement receives unanchored floating windows, they default to origin `(0, 0)`.
  - *Mitigation:* In [`rules.lua`](file:///home/realdhiru/nix/dotfiles/hypr/rules.lua), declare `hl.window_rule({ match = { modal = true }, float = true, center = true })` and `hl.window_rule({ match = { xwayland = true, float = true }, center = true })`.
- **Wallpaper Cycling In-Flight Pointer (`target_wallpaper.txt`) Invalidation:**
  - *Symptom:* Pressing next/prev wallpaper cycle keybinds jumps to a photo wallpaper in a distant category instead of cycling around the currently active wallpaper (e.g. an active GIF).
  - *Root Cause:* `cycle_wallpaper.sh` cached its target destination in `~/.cache/target_wallpaper.txt` to support rapid sub-second key repeat. However, when the user selected a new wallpaper via `WallpaperPicker.qml` or `wallpaper.sh set`, `target_wallpaper.txt` was never updated or cleared. Any subsequent cycle keypress read the stale target file from earlier sessions, overriding the actual live active wallpaper path in `current_wallpaper.txt`.
  - *Mitigation:* In `cycle_wallpaper.sh`, invalidate `target_wallpaper.txt` if `current_wallpaper.txt` has a newer modification time or if `target_wallpaper.txt` is older than 2 seconds. In `set.sh`, unconditionally delete `target_wallpaper.txt` whenever any non-cycling wallpaper application occurs (`[ -z "${FORCE_CYCLE:-}" ] && rm -f "$CACHE_DIR/target_wallpaper.txt"`).
- **WirePlumber Diagnostic Event-Driven Telemetry in Systemd:**
  - *Symptom:* Intermittent audio loss or dangling virtual sink forward links cannot be debugged from standard journal logs because WirePlumber runs at warning/notice log level (`W`) by default with zero linking decisions recorded.
  - *Root Cause:* WirePlumber 0.5 uses granular logging topics (`s-linking`, `s-default-nodes`) rather than simple global verbosity flags. Without setting `WIREPLUMBER_DEBUG`, session item linking, target resolution failures, and default device elections emit no journal entries.
  - *Mitigation:* Declare `systemd.user.services.wireplumber.environment.WIREPLUMBER_DEBUG = "I,s-linking:D,s-default-nodes:D"` in `modules/system/services.nix`. WirePlumber automatically emits timestamped linking decisions directly to the user journal without file I/O overhead.
- **`awww` Scaling Filter Selection & Disconnected Disk Cache Scan (`--outputs` Invariant):**
  - *Symptom:* Setting animated GIF wallpapers stalls the desktop for 30–40 seconds at 100% CPU, and applying even small static images takes hundreds of milliseconds or hangs.
  - *Root Cause 1 (CPU Lanczos3 Multi-Frame Convolution):* `awww img` defaults to `--filter Lanczos3`. For an animated GIF with 90–350 frames at 2880×1620, `awww` runs intensive 3-lobed Sinc convolution in software across every individual frame sequentially. A 90-frame GIF takes 32.65 seconds of pure CPU time.
  - *Root Cause 2 (Disconnected Cache Loading Trap):* When `awww img` is called without `--outputs <mon>`, it executes `update_disconnected_caches()` (in `common/src/ipc/mod.rs`), which opens `~/.cache/awww/<version>/` and synchronously `fs::read()`s *every* `*_crop_Argb` frame cache file on disk. If multi-frame GIF frame files accumulate (e.g. 867 MB), every single subsequent wallpaper push—including small static photos—synchronously loads 867 MB into memory, stalling execution.
  - *Mitigation:* In `backend/set.sh`, always resolve active outputs (`OUT_JOINED`) and pass `--outputs "$OUT_JOINED"` to `awww img`. Pass `--filter Nearest` for `.gif` files (instant decode, 0.4s cold, 0.18s warm) and `--filter Bilinear` for static images (0.06s). Configure `awww-daemon` with `--no-cache --format argb` in systemd (`home.nix`) to prevent unbounded disk cache accumulation.
- **Systemd Unit Template Instance Unescaping Trap (`%I` vs `%i`):**
  - *Symptom:* `mpvpaper@eDP-1.service` repeatedly fails with `[-] :/ sorry about this but we can't seem to find any output` and exits with code 1 / `start-limit-hit`.
  - *Root Cause:* In systemd unit templates, `%I` represents the unescaped instance name, where dashes `-` are unescaped to directory slashes `/` (i.e. `eDP-1` becomes `eDP/1`). `%i` represents the verbatim instance string. Passing `%I` to `mpvpaper` causes it to search for non-existent Wayland output `eDP/1`.
  - *Mitigation:* Always use `%i` for hardware display outputs in systemd unit templates (e.g. `mpvpaper@.service`).
- **Wallpaper Kill Mode Dynamic Opacity Override & Restoration:**
  - *Symptom:* Un-killing the wallpaper previously attempted `hyprctl reload` to re-read `rules.lua` and flush temporary overrides.
  - *Current Architecture:* Wallpaper un-kill now directly re-enables compositor decorations and blur dynamically via `hl.config({ decoration = { blur = { enabled = true }, shadow = { enabled = true } }, animations = { enabled = true } })` and reloads terminal opacity without a full `hyprctl reload`, avoiding compositor state disruption and texture re-allocations.
- **Wine/Proton UWP Runtime & Repack Post-Install Verification Traps:**
  - *Symptom:* Repacked UWP games fail during installation post-checks or crash during boot with recursion / stack overflows.
  - *Findings:* FitGirl post-install verification gates (`QuickSFV.exe` case-mismatches and `dxwebsetup.exe`) fail under Wine and trigger silent rollbacks; neutered by stubbing gate binaries post-file phase. Missing UWP VC++ desktop runtime DLLs (`MSVCP140_APP`, `VCRUNTIME140_APP`) can be satisfied via renamed desktop CRTs. However, game-specific UWP hooks (`LootboxUWP64.dll` hooking `combase!RoGetActivationFactory`) may recurse unboundedly in Wine without real UWP runtime implementations, producing thread stack overflows.
