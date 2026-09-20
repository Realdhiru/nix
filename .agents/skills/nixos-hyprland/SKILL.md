---
name: NixOS / Hyprland Rice & Configuration
description: High-density operational reference for maintaining the user's NixOS desktop, Hyprland rice, and QuickShell widgets.
---

# NixOS / Hyprland Rice & Configuration

## 1. Operating Rules & Discipline

1. **Update Docs on Task Completion**:
   - Concise summary in `~/nix/CHANGELOG.md` under the current date.
   - Architectural/technical shifts in `~/nix/docs/decisions.md`.
   - Update `SKILL.md` / `AGENTS.md` only for systemic non-negotiables.
2. **Manual Git Control**: Do **NOT** stage, commit, or push automatically. The user commits and pushes manually.
3. **High-Density / Caveman Communication**:
   - Zero filler, zero pleasantries, high semantic density.
   - Exact file links (`file:///...`), exact commands, zero speculative hallucination.
   - Final turn summaries must be brief, structured bullet points.

## 2. Invariant Hardware & Architecture Policies

- **Power Authority**: TLP 1.9.1 is sole authority (`power.nix`). `asusd` only enforces 80% charge threshold (`charge_control_end_threshold = 80`).
- **Lid Policy**: `HandleLidSwitch = "ignore"`. Lid never suspends. Suspend is manual (`Shift + Esc`).
- **Balanced Battery Profile**: `balance_performance`, Turbo `1`, Platform Profile `balanced`, ASPM `powersupersave`.
- **QuickShell IPC**: Native C++ event-driven bindings only (`Quickshell.Hyprland`, `Pipewire`, `FileWatcher`). Never use bash polling loops inside QML.
- **Single-Pass Popup Scaler**: Scaler in popups uses `currentWidth: Screen.width`. Never use `Config.masterWidth` (causes clipping via double scaling).
- **Out-of-Store Symlinks**: Home Manager `mkOutOfStoreSymlink` targets live `~/nix/dotfiles/` for zero-rebuild live updates.
- **Hardware Quirks**:
  - ASUS OLED brightness keys: rebound after hybrid-sleep in `hosts/nixos/hardware/asus.nix`.
  - Sonix Webcam: `v4l2loopback` `/dev/video10` pass-through via `hosts/nixos/hardware/sonix-webcam.nix`.
  - WirePlumber: `50-disable-libcamera.conf` disables libcamera to avoid UVC stream collision.

## 3. Workflow & Verification Commands

```bash
# Lint QML widgets
nix build ~/nix#checks.x86_64-linux.qml-lint

# Rebuild NixOS with health gate
rebuild "<commit message>"

# Dry-run configuration
sudo nixos-rebuild dry-run --flake ~/nix#nixos

# Non-destructive Hyprland/QuickShell reload
~/.config/hypr/scripts/reload.sh

# Audio subsystem recovery
~/.config/hypr/scripts/fix_audio.sh
```
