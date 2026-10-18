---
title: Compositor Rules & Opacity
tags: [compositor, rules, opacity, glassmorphism, visual-hierarchy]
---

# Compositor Rules and Opacity: The Glass Hierarchy

Desktop aesthetics in our system are governed by a strictly calibrated visual hierarchy declared in `dotfiles/hypr/rules.lua`. Windows are not given arbitrary transparency; each application category is assigned an opacity value mapped to its functional role.

---

## 1. The Opacity Tiers

| Tier Name | Opacity Value | Target Applications | Design Rationale |
| :--- | :--- | :--- | :--- |
| **Deep Ambient Glass** | `0.47` – `0.50` | Antigravity, ChatGPT Desktop | Ambient sidecars; high backdrop blur allows them to float non-intrusively. |
| **Soft Glass** | `0.57` – `0.60` | Brave Web Apps, PCManFM-Qt | Interactive file navigation; balanced backdrop transparency with high text clarity. |
| **Knowledge Base** | `0.65` | **Obsidian** | Long-form reading and note-taking; subtle glass texture without causing eye strain. |
| **Terminal Glass** | `0.70` | Alacritty | High code contrast against syntax tokens while retaining wallpaper presence. |
| **Solid Override** | `1.00` | Fullscreen Games, Videos, Battery Saver | Completely disables alpha blending to conserve battery and GPU compute cycles. |

---

## 2. Invariant Design Rules

1. **Layer Blur Enforcement**: All QuickShell surfaces (`quickshell`, `qs-.*`) are matched with `ignore_alpha = 0.05` in `rules.lua`, ensuring hardware Kawase blur is rendered behind every surface.
2. **Anti-Bleed Layering**: Translucent glass cards are backed by an anti-bleed surface fill (`crust` at 0.16–0.18). This prevents high-contrast wallpaper linework from bleeding through and degrading text legibility.
3. **Zero One-Off Styling**: Opacity and blur settings must never be altered for an individual widget in isolation; visual changes must be applied globally across the desktop using shared design tokens.

## Related Nodes
- [[Lua Configuration Model]]
- [[Theme.qml & Semantic Roles]]
- [[Wallust Dynamic Palette Engine]]
