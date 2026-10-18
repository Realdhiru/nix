---
title: QML Scene-Graph Coordinate Gating
tags: [trap, quickshell, qml, scene-graph, geometry, layouts]
---

# QML Scene-Graph Coordinate Gating: Eliminating Frame-0 Snaps

A non-obvious bug in QML carousels and popup components: **the Frame-0 layout snap or negative coordinate clamp**.

---

## 1. Root Cause: Offscreen Preloading vs Visual Scene Graph

To make popups feel instantaneous, developers often preload them offscreen (`visible: false`).

- In Qt Quick, visual items set to `visible: false` exist outside the active visual scene graph.
- Outside the scene graph, container widths and coordinate transforms resolve to `0`.
- If an imperative script invokes `ListView.positionViewAtIndex()` or layout centering math while `view.width == 0`, coordinate calculations divide by zero or clamp to invalid negative coordinate spaces.
- When the popup is opened, the user sees a jarring visual snap as items jump from `(0, 0)` to their calculated coordinates on Frame 1.

---

## 2. The Architectural Invariant

All carousel positioning passes and dynamic coordinate math must be strictly gated:

```qml
// Non-negotiable scene-visibility guard:
if (window.visible && view.width > 0) {
    view.positionViewAtIndex(index, ListView.Center);
}
```

Additionally, `Scaler` instances inside popup windows must reference single-pass screen width (`currentWidth: Screen.width`) rather than master device bounds (`Config.masterWidth`) to prevent double-scaling multiplication ($1.33 \times 1.33 = 1.77$).

## Related Nodes
- [[QuickShell Event-Driven IPC]]
- [[TopBar & Dynamic Workspaces]]
- [[Intel GPU Ring Buffer Trap]]
