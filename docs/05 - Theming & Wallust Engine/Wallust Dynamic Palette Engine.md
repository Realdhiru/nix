---
title: Wallust Dynamic Palette Engine
tags: [theming, wallust, colors, rust, k-means, color-spaces]
---

# Wallust Dynamic Palette Engine: Color Extraction Architecture

Desktop theming in our system—including terminal palettes, QuickShell cards, launcher menus, and audio visualizers—is generated dynamically from the active wallpaper.

This document outlines why we deprecated Matugen and details the color extraction pipeline implemented via **Wallust**.

---

## 1. Why Matugen Was Deprecated

In earlier iterations of our desktop, we evaluated `matugen` (an implementation of Google's Material You tonal algorithm). In daily use, several flaws emerged:

1. **Monotone / Muddy ANSI Palettes**: Material You derives its entire palette from a single dominant seed color. When applied to complex wallpapers (nature landscapes, cyberpunk neon, or anime art), terminal colors became flat and repetitive. Standard ANSI semantic roles (red for errors, green for success) lost contrast and visual distinction.
2. **False Light Leaks**: Matugen occasionally extracted high-lightness accent tones on dark wallpapers, violating our requirement for a permanent dark theme.
3. **Monolithic Scripting**: Matugen was tightly coupled into a 220+ line shell script mixing wallpaper daemon controls with color extraction.

---

## 2. The Wallust Architecture

**Wallust** is a standalone CLI tool written in Rust that performs **K-Means clustering in Lch colorspace** (`lchansi` + `ansidark16`):

- **Perceptual Contrast**: Evaluates lightness, chroma, and hue across wallpaper pixel clusters to extract 16 distinct ANSI terminal colors (`color0` through `color15`) with mathematical contrast validation.
- **Execution Speed**: Color extraction and template generation completes in **under 120 milliseconds**.
- **Permanent Dark Mode Rule**: Theme generation is locked to dark mode (`saliencedark16`). Wallpaper switches never trigger automatic light mode.

---

## 3. Template Generation Pipeline

When a new wallpaper is selected, Wallust generates configuration files from templates located in `dotfiles/wallust/templates/` and writes them into `~/.cache/theme/`:

- `hyprland-colors.conf`: Active window border colors and highlight accents.
- `alacritty.toml`: Terminal emulator palette, dynamically reloaded via inotify.
- `fuzzel.ini`: Application launcher color palette.
- `colors.json`: Master JSON object consumed dynamically by QuickShell via `Theme.qml`.

## Related Nodes
- [[Theme.qml & Semantic Roles]]
- [[Compositor Rules & Opacity]]
- [[QuickShell Event-Driven IPC]]
