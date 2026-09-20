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
          ├─ monitors: dynamic power monitor (~/.cache/hypr_power_monitor.conf)
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
6. `hypridle`, `cliphist` (text + image watchers), `equalizer.sh --init`

## 3. QuickShell Shell

```text
Shell.qml (loader)
  └─ Main.qml (StackView: cache-then-push)
      ├─ TopBar.qml (bars, native Hyprland workspace IPC, NotifTicker live notifier)
      ├─ Floating.qml (popup roots: layoutWidth / layoutHeight bound)
      ├─ SysData.qml (power-profile telemetry & live listener)
      ├─ MatugenColors.qml (reads ~/.cache/matugen/qs_colors.json)
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
