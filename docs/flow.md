# Execution Flows

End-to-end flows for system execution and recovery.

---

## 1. Boot → Hyprland

```text
BIOS → systemd-boot → NixOS (systemd)
  ├─ services.tlp starts (charger state switches AC/BAT via udev rule)
  └─ getty@tty1 → zsh (shell.nix initContent, XDG_VTNR=1) → exec start-hyprland
      └─ Hyprland reads ~/.config/hypr/hyprland.lua (symlinked: ~/nix/dotfiles/hypr)
          ├─ require("env", "startup", "keybinds", "rules", "input", "appearance", "misc")
          ├─ monitors: `refresh_monitor.sh` reads active outputs and advertised modes; monitor intent lives under `$DESKTOP_STATE_DIR/monitors/intent.json`
          └─ shaders: persisted screen shader (~/.cache/current_shader.conf)
  └─ systemd user services start (default.target / hyprland-session.target):
      focustime-daemon, easyeffects, playerctld, camera-loopback
```

## 2. Startup (`dotfiles/hypr/startup.lua`, sequential)

1. `dbus-update-activation-environment` (Wayland → D-Bus sync for notifications)
2. `systemctl --user start hyprland-session.target`
3. `quickshell -p quickshell/Shell.qml` (TopBar & master window render concurrently)
4. `hyprctl setcursor Bibata-Modern-Ice 32`
5. `boot_wallpaper.sh` (warm-cache push ~0.2s vs cold ~27s; awww/mpvpaper lifecycle)
6. `hypridle`, `equalizer.sh --init`

Clipboard recording is started separately by Home Manager user services
`cliphist-text-watcher` and `cliphist-image-watcher`, attached to
`graphical-session.target` and restarted by systemd if either watcher exits.

## 3. QuickShell Shell

```text
Shell.qml (loader)
  └─ Main.qml (StackView: cache-then-push)
      ├─ TopBar.qml (bars, native Hyprland workspace IPC, NotifTicker live notifier)
      ├─ Floating.qml (popup roots: layoutWidth / layoutHeight bound)
      ├─ SysData.qml (power-profile telemetry & live listener)
      ├─ Theme.qml (reads ~/.cache/theme/colors.json)
      └─ Subsystems: battery, volume, music, network, wallpaper, focustime, monitors, calendar, clipboard
```

- **Popup toggle:** `qs_manager.sh toggle <name>` (IPC into Main.qml; respawns shell if dead).
- **Reload:** `reload.sh` (non-destructive; reloads Hyprland and refreshes QuickShell without unmapping surfaces).

## 4. Emergency Recovery

| Condition | Recovery Path |
| :--- | :--- |
| Bad system generation | Run `sudo nixos-rebuild switch --rollback --flake ~/nix#nixos` or select previous generation at bootloader. |
| Terminal unavailable | Switch TTY (`Ctrl + Alt + F2..F6`), login as user. |
| QuickShell crashed | Press `SUPER + ALT + R_ALT` to respawn, or run `~/.config/hypr/scripts/reload.sh --quickshell`. |
| Audio hung | Press `SUPER + CTRL + SHIFT + V` to run `fix_audio.sh` (reloads ALSA/HDA kernel modules). |

## 5. Safe NixOS Rebuild

Use the `rebuild` shell function from `modules/home/shell.nix` for system
changes. It builds the current tree through a `git+file` flake reference,
records the current generation, switches, then runs `scripts/health-check.sh`.
It runs `nix flake check` before building. By default it never stages or commits.
`rebuild -c [message]` commits only changes already staged by the user, and only
after the switch passes health checks; it never runs `git add`, ignores
unrelated unstaged work, and stops if a staged path also has unstaged edits. A build failure leaves
the active generation unchanged. The previous generation remains available
for rollback and from the boot menu; garbage collection retains generations
for 14 days.

## 6. Post-Switch Health Gate

The health check verifies Hyprland, launches an isolated Alacritty probe, and
checks critical user services. Critical failures trigger automatic rollback;
warnings are reported without rollback. The report is written under
`~/.cache/nix_health_*.log`.

## 7. Manual Recovery

If an activated generation is unusable, select the previous generation from
the boot menu or run:

```bash
sudo nixos-rebuild switch --rollback --flake ~/nix#nixos
```

The failed generation remains available for diagnosis and boot during the
14-day retention window. See
[`debugging.md`](debugging.md) for investigation procedures.
