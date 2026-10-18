---
title: Coffee Mode
tags: [power, idle-inhibit, systemd, quickshell, automation]
---

# Coffee Mode: Persistent Systemd Idle Inhibition

During long presentations, video streaming, or intensive code reviews, automated screen dimming and lockscreen activation are disruptive.

We implemented **Coffee Mode** (`SUPER + CTRL + U`) to provide persistent idle inhibition.

---

## 1. Implementation Architecture

1. **Systemd Inhibitor Lock**:
   When toggled via `dotfiles/hypr/scripts/power.sh`, the script acquires a native systemd inhibitor:
   ```bash
   systemd-inhibit --what=idle:sleep \
     --who=idle-inhibit-toggle \
     --why="Coffee mode (idle inhibit)" \
     --mode=block sleep infinity
   ```
2. **Canonical State Persistence**:
   The active mode is written to `~/.cache/quickshell/state.json` under `modes.coffee`.
3. **Session Restoration**:
   If Coffee Mode is active and Hyprland reloads, QuickShell restarts, or the machine reboots, `restore_state.sh` checks `state.json` and automatically re-engages the systemd inhibitor.
4. **Visual Indicator**:
   When active, an amber coffee cup glyph is embedded directly within the TopBar battery status pill.

## Related Nodes
- [[TLP Exclusive Authority]]
- [[TopBar & Dynamic Workspaces]]
- [[ASUS Hardware Quirks]]
