---
title: TopBar & Dynamic Workspaces
tags: [quickshell, topbar, workspaces, layout-geometry, marquee]
---

# TopBar and Dynamic Workspaces

The TopBar (`dotfiles/hypr/scripts/quickshell/TopBar.qml`) serves as the primary status and telemetry center on our desktop.

This document details the workspace allocation mathematics and geometry handling implemented in the bar.

---

## 1. Dynamic Workspace Tracking

Many custom bar setups either hardcode a fixed 1–10 workspace layout or break visual proportions when users switch to dynamic workspaces.

In our TopBar, workspace calculation is dynamic:
```javascript
Math.max(6, focusedId, maxOccupiedId)
```
- **Consistent Visual Footprint**: Maintains a clean 1–6 baseline layout during standard workflows.
- **Dynamic Expansion**: Automatically expands when windows are opened on workspaces beyond 6 without clipping container boundaries or displacing adjacent status pills.
- **Single-Flight Debounce**: Coalesces rapid bursts of Hyprland IPC events via a 16ms timer (`wsDebounceTimer`), preventing frame-to-frame layout jitter when rapidly cycling workspaces.

---

## 2. Content-Derived Music Geometry

A subtle engineering defect in custom status bars is **variable-width music widget clipping**:
- If a song title is extremely short (e.g. `命盤`), naive layout containers collapse, causing timeline text (`01:24 / 06:45`) or media buttons to be clipped.
- If a song title is very long, it expands aggressively and pushes adjacent status icons off the edge of the bar.

### Our Solution
- The minimum width of the media container (`mediaInfoColumn`) is anchored strictly to non-negotiable text content (`timeText.implicitWidth` + playback buttons).
- Short titles can **never** shrink the column below the threshold required to render timestamps.
- Long titles are clipped to a maximum container bound and smoothly marquee-scrolled using native QML text animations.

## Related Nodes
- [[QuickShell Event-Driven IPC]]
- [[Widgets Breakdown]]
- [[MPV MPRIS Pipeline]]
