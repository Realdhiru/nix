---
title: QuickShell Desktop Map of Content
type: moc
tags: [moc, quickshell, qml, ui, widgets, index]
---

# QuickShell Desktop Map of Content

The native C++ Qt/QML desktop shell architecture.

---

## Core Documents

1. [[QuickShell Event-Driven IPC]]
   - The complete elimination of shell polling loops.
   - Sub-8ms C++ event bindings to Hyprland and PipeWire.

2. [[TopBar & Dynamic Workspaces]]
   - Dynamic workspace layout math (`Math.max(6, focusedId, maxOccupiedId)`).
   - Content-minimum music container geometry and marquee scrolling.

3. [[Widgets Breakdown]]
   - Catalog and architecture of all 6 custom QML popups (Battery dial, Network radial manager, 3D carousel, Equalizer, Focus timer, Sunset controller).

## Related Domains
- [[Compositor & Hyprland MOC]]
- [[System Architecture MOC]]
