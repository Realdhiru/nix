# CHANGELOG

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