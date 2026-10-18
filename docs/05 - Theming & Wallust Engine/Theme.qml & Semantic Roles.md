---
title: Theme.qml & Semantic Roles
tags: [theming, quickshell, qml, design-tokens, reactivity]
---

# Theme.qml and Semantic Design Roles

When extracting raw color palettes from wallpapers, widgets cannot simply bind to arbitrary ANSI slots like `color4` or `color12`. Professional user interface design requires **semantic design tokens** (e.g. Surface, Primary, Secondary, Background, Error, Text).

This document explains how `Theme.qml` translates raw Wallust color arrays into reactive UI tokens across QuickShell.

---

## 1. The Reactive FileView Architecture

In `dotfiles/hypr/scripts/quickshell/Theme.qml`, QuickShell establishes an inotify watcher on the generated color file:

```qml
FileView {
    path: StandardPaths.cache + "/theme/colors.json"
    watchChanges: true
    onFileChanged: reload()
}
```

When Wallust writes a new `colors.json` to the cache directory, `FileView` intercepts the event, reloads the JSON buffer, and updates the token properties reactively.

---

## 2. Mapping ANSI Slots to Semantic Roles

`Theme.qml` establishes clean semantic mappings:

```qml
// Design token definitions:
readonly property color primary: colors.color4    // Dynamic accent color
readonly property color surface: colors.color0    // Elevated card surface
readonly property color crust: colors.background  // Deep anti-bleed foundation
readonly property color text: colors.foreground   // High-contrast readable foreground
readonly property color error: colors.color1      // Standard red warning accent
```

### The Architectural Invariant: Zero Hardcoded Colors
Hardcoded hex colors (`#1e1e2e`, `#89b4fa`) are strictly prohibited in widget files. Every button, slider rail, and text element binds directly to `Theme.primary` or `Theme.surface`.
- Changing the desktop wallpaper instantly updates all UI components across the screen without requiring a shell reload.

## Related Nodes
- [[Wallust Dynamic Palette Engine]]
- [[Compositor Rules & Opacity]]
- [[QuickShell Event-Driven IPC]]
