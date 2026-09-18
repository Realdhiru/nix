# Execution Flows

End-to-end flows for every subsystem. These describe the **current code**
(verified 2026-08-16). When in doubt, trace the code — flow here only gets
updated when a change ships.

---

## 1. Boot → Hyprland

```
BIOS → systemd-boot → NixOS (systemd)
  └─ services.tlp starts (charger state decides AC/BAT via udev rule)
  └─ getty@tty1 → zsh (shell.nix initContent, XDG_VTNR=1) → exec start-hyprland
      └─ Hyprland reads ~/.config/hypr/*.conf  (symlinked: ~/nix/dotfiles/hypr)
          ├─ hyprland.conf → source env.conf layout.conf input.conf misc.conf
          │                 rules.conf keybinds.conf appearance.conf
          ├─ startup.conf (order!) → see startup section below
          └─ idle → hypridle.conf
  └─ home-manager user services start (default.target):
      focustime-daemon, vscodium-settings-sync, easyeffects, playerctld
```

## 2. Startup (startup.conf, in order)

1. `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP`
   → browsers/Electron apps can send notifications.
2. `killall -q dunst mako swaync hyprnotify || true` → Quickshell owns
   notifications (NotifTicker), nothing else may hold the D-Bus namespace.
3. `lock.sh` → hyprlock setup + `quickshell -p Lock.qml` standalone instance
   (WlSessionLock). Lock screen itself draws the live wallpaper.
4. `boot_wallpaper.sh` → warm-cache wallpaper push (image/GIF/video), then
   ensure_awww starts the mpvpaper daemon if needed. Cold ~27s → warm ~0.2s.
5. `hypridle` (idle policy from hypridle.conf), `cliphist` watchers (text +
   image), `quickshell -p Shell.qml` (the shell: TopBar + popups),
   `equalizer.sh --init` (apply saved EQ state), `setcursor`, `lid-monitor.sh`.

## 3. Quickshell shell

```
Shell.qml (thin loader)
  └─ Main.qml — StackView
      ├─ TopBar.qml (bars, wsDaemon socket client, NotifTicker singleton
      │             — the LIVE notifier; NotificationPopups.qml is dead code)
      ├─ Floating.qml — popup windows (roots bind layoutWidth/layoutHeight)
      │    └─ per-subsystem popups toggled by qs_manager.sh IPC
      ├─ SysData.qml — battery/power state; profile picker → apply_profile.sh
      ├─ MatugenColors.qml — reads ~/.cache/matugen/qs_colors.json
      ├─ Caching.qml (qs_ensure_cache), Config.qml, Scaler.qml, WindowRegistry.js
      └─ watchers/ — one Process watcher per widget (volume, battery, weather,
                     workspaces, focus, music, network, notifications…)
```

- Popup toggle: `qs_manager.sh toggle <name>` → if shell dead, respawn it.
- Reload: `reload.sh` → `pkill -f "quickshell/watchers"` → respawn shell.

## 4. Wallpaper pipeline

```
set_wallpaper.sh (picker)            boot_wallpaper.sh (login)
      │  WALL=$1 → cache/current_wallpaper.txt        │  warm push from cache
      ├─ ensure_awww.sh (single owner, idempotent)    │
      │    └─ awww-daemon --format xrgb → mpvpaper    │
      ├─ matugen color hex|image → config.toml (scheme-fidelity)
      ├─ matugen/extract_raw_colors.sh → qs_colors.json (atomic .tmp write,
      │    6-char hex, 22 keys, O(1) 2x1 resize, saturation guard)
      └─ Lock.qml watches current_wallpaper.txt →
           Image | AnimatedImage(GIF) | MediaPlayer(video) + MultiEffect blur
```

## 5. Power management

```
AC/BAT authority (sole): udev rule on ucsi-source-psy-USBC000:001
  online=1 → tlp ac   online=0 → tlp bat
  (TLP: governor, EPP, boost, platform profile, runtime PM, charge 75/80%)

lid-monitor.sh (udevadm button monitor, no polling)
  lid close → apply_profile.sh power-saver   lid open → restore by charger
        │                                        (AC → performance, else balanced)
BatteryPopup/SysData.qml profile picker → apply_profile.sh <name>
  apply_profile.sh: set_epp.sh (governor FIRST — EBUSY otherwise),
                    turbo, monitor RR, shader/blur/shadow cut,
                    pre-saver state in ~/.cache/qs_pre_saver_shader.conf
Suspend: manual Shift+Esc only.
```

## 6. Focus time

```
focus_daemon.py (systemd user, Restart=always)
  hyprctl activewindow (socket re-resolved) → accumulate per-app seconds
  → state files in ~/.local/state/quickshell/focustime (QS_STATE_FOCUSTIME)
FocusTimePopup: refuses stale files (date must match today)
  stats via get_stats.py (off-by-one/double-count fixed)
toggle: SUPER CTRL F (qs_manager.sh toggle focustime)
```

## 7. Spotify stack

```
spicetify-nix (flake, home-manager shared module)
  ├─ Liquify V2 → ~/.cache/spotify/Default/Local Storage/leveldb (62 keys)
  │    seed extension writes missing keys only (never clobbers UI edits)
  ├─ spicy-lyrics + rAF fallback extension (100ms setTimeout race)
  └─ renderer: investigation doc only (no forced GPU profile)
music widgets: playerctld + music_info.sh / player_control.sh; equalizer.sh
```

## 8. EasyEffects / EQ

```
systemd (HM): easyeffects --load-preset live_eq (preset dir:
  ~/.local/share/easyeffects/output — NOT ~/.config)
equalizer.sh --init | <state>:
  is-active check (systemctl) → hand preset to the running instance via
  `easyeffects -l` (socket handoff, no second instance, no pgrep)
```

## 9. Notifications

```
watcher → D-Bus org.freedesktop.Notifications → NotifTicker.qml (singleton)
  → TopBar ticker. NotificationPopups.qml is DEAD CODE — don't recreate.
```

## 10. Lock screen

```
lock.sh → hyprlock readiness + quickshell Lock.qml (own instance, WlSessionLock)
  Lock.qml: current_wallpaper.txt → Image / AnimatedImage / MediaPlayer
    + MultiEffect blur + dimmer + clock/date
  keybinds: SUPER F2 lock; CTRL ALT SHIFT DEL = locked submap; SHIFT ESC = suspend
```

## 11. VSCodium settings

```
live: ~/.config/VSCodium/User/settings.json (real file, copied by
  home.activation.vscodiumSettings after writeBoundary — home-manager symlinks
  are read-only for VSCodium)
repo: vscodium-settings-sync systemd service → dotfiles/vscodium/sync_settings.sh
  → commit-ready diff in ~/nix/dotfiles/vscodium/settings.json (never rebuilds)
```

## 12. Rebuild (safety flow)

```
rebuild <msg> (zsh, shell.nix initContent)
  1. record known-good:  ~/.cache/nix_rebuild_log  (<ISO time> <gen link> <git HEAD>)
                         git tag -f known-good   (tags the RUNNING generation's commit)
  2. git add -A → commit (skip if clean) — commit BEFORE build so the flake
     builds a clean tree: generation ↔ commit correlation (gen dirs have no
     embedded revision)
  3. sudo nixos-rebuild build --flake .#nixos
     failure → ABORT, nothing activated, previous gen still current
  4. sudo nixos-rebuild switch --flake .#nixos   (store-cached after step 3)
  5. health-check.sh $start   (post-switch gate, journal scoped to $start)
     CRITICAL (→ auto-rollback):
       - Hyprland dead (hyprctl + pgrep both fail)
       - wezterm probe: cli rc≠0 | no gui pid | pid-attributed i915 GPU HANG
     WARNING (→ report only, NEVER rolls back):
       - post-switch GPU HANGs from other processes
       - quickshell down | pipewire/pipewire-pulse/wireplumber inactive
       - xdg-desktop-portal inactive (known broken 2026-08-16, non-blocking)
  6. CRITICAL → sudo nixos-rebuild switch --rollback
       → verify profile == recorded gen
       → print: failed gen (kept selectable/bootable), restored gen,
         health log, investigation commands
```

- Probe design (health-check.sh): isolated `wezterm start --always-new-process
  -- /bin/sh -c 'sleep 8'`; scope GPU-HANG count to `[start, now]` AND probe
  pid. NEVER kills/touches pre-existing wezterm instances.
- Bad generation is never deleted: still in profile (`--switch-to-generation N`
  returns to it) and still has a boot entry (bootctl).
- `clean()` = `nix-collect-garbage --delete-older-than 14d`; nix.gc
  automatic weekly also 14d — keeps rollback target bootable.

## 13. Recovery cheatsheet

| Situation | Commands |
|---|---|
| Terminal unavailable, session alive | TTY: `Ctrl+Alt+F2..F6`, login as realdhiru (zsh). Or run the last-good binary directly: `/nix/store/xcda1bvbn8afhmxk34fknf4dwwqq6k57-wezterm-0-unstable-2026-07-16/bin/wezterm-gui`. Or VSCodium integrated terminal. |
| Graphical session dead, TTY works | `Ctrl+Alt+F2` login → `sudo nixos-rebuild switch --rollback` → `sudo reboot`; tty1 auto-starts Hyprland. |
| Boot previous generation (menu hidden, timeout=0) | `bootctl list` → pick entry (e.g. `nixos-74d6…f5.conf`, the 7.1.4/old-userland gen) → `sudo bootctl set-default nixos-74d6…f5.conf` → `reboot`. |
| Switch back from TTY (no reboot) | `sudo nixos-rebuild switch --rollback` (previous gen) or `sudo nixos-rebuild switch --switch-to-generation N`. |
| Re-enter a rolled-back (failed) gen | `sudo nixos-rebuild switch --switch-to-generation <that N>` — kept on purpose for investigation. |
| Investigate the failure | `journalctl -k --since '<switch time>' \| grep -E 'GPU HANG|call trace'`; `cat ~/.cache/nix_rebuild_log`; latest `~/.cache/nix_health_*.log`; `bootctl list` for gen↔kernel mapping. |
