---
title: Emergency Recovery Protocol
tags: [recovery, emergency, tty, audio, rollback, runbook]
---

# Emergency Recovery Protocol: Operational Runbook

When hardware locks up, an experimental shader crashes, or the audio driver hangs, this runbook outlines the recovery paths built into our system.

---

## 1. Fast Keybinding Escapes

| Keybinding | Action | Functional Mechanism |
| :--- | :--- | :--- |
| `SUPER + ALT + R_ALT` | QuickShell Respawn | Forcefully reaps stray QuickShell processes and triggers a clean cold restart via `qs_manager.sh reload`. |
| `SUPER + CTRL + SHIFT + V` | Audio Recovery | Executes `fix_audio.sh` to unbind ALSA/HDA kernel modules and restart PipeWire. |
| `SUPER + R` | Frame-0 Config Reload | Evaluates Hyprland Lua configuration and updates window opacities in ~15ms without closing running applications. |

---

## 2. Low-Level TTY Recovery

If the display server or graphics pipeline freezes completely:
1. Press `Ctrl + Alt + F2` (or `F3` through `F6`) to drop out of graphical mode into a raw Linux virtual terminal (TTY).
2. Log in with user credentials.
3. Roll back to the previous known-good generation immediately:
   ```bash
   sudo nixos-rebuild switch --rollback --flake ~/nix#nixos
   ```
4. Return to TTY1 (`Ctrl + Alt + F1`).

## Related Nodes
- [[The rebuild() Function]]
- [[Automated Rollback Safeguards]]
