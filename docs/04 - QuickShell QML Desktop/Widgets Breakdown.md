---
title: Widgets Breakdown
tags: [quickshell, widgets, ui, architecture, components]
---

# Widgets Breakdown: The QuickShell Desktop Component Catalog

This document catalogs the custom QML desktop widgets built natively on QuickShell under `dotfiles/hypr/scripts/quickshell/`.

---

## 1. Battery Radial Dial (`battery/BatteryPopup.qml`)
- **Telemetry**: Displays charge percentage, live discharge rate in Watts (e.g. `11.4W`), overall battery health percentage, and time to full/empty derived directly from `Quickshell.Services.UPower`.
- **Profile Controls**: Embedded buttons toggle between hardware power profiles: **Power Saver**, **Balanced**, and **Performance**.
- **Mode Indicators**: Directly hosts active state indicators (such as the Coffee Mode icon) inside the battery pill, avoiding fragmented notification icons.

## 2. Network Radial Manager (`network/NetworkPopup.qml`)
- **Connectivity**: Unified interface coordinating Wi-Fi, Ethernet, and Bluetooth devices.
- **Scanning**: Scans active broadcasting 802.11 SSIDs, displaying signal strength, frequency band, and security flags.
- **Sound Feedback**: Emits audio cues on device connect/disconnect, while muting repetitive tab-switching sound effects.

## 3. 3D Wallpaper Parallax Carousel (`wallpaper/WallpaperPicker.qml`)
- **Browsing**: Interactive 3D carousel allowing visual browsing of local wallpapers and saved favorites.
- **Dynamic Search**: Integrated search engine capable of querying and downloading wallpapers directly into the system cache.

## 4. Media Player & Equalizer (`music/MusicPopup.qml`)
- **Playback**: Vinyl record rotation animation tied to MPRIS play/pause states.
- **DSP Controls**: 10-band native PipeWire DSP equalizer sliders ($31\text{Hz}$ to $16\text{kHz}$) with instant acoustic curve presets (Flat, Bass, Vocal, Rock, Jazz).

## 5. Focus Time Tracker (`focustime/FocusTimePopup.qml`)
- **Productivity**: Integrated Pomodoro timer supporting custom focus durations, break timers, and productivity tracking.

## 6. Night Light & Sunset Controller (`sunset/SunsetPopup.qml`)
- **Display Adjustments**: Continuous smooth sliders adjusting color temperature ($1000\text{K}$ to $6500\text{K}$), gamma, saturation, and CRT retro shaders powered by `hyprsunset`.

## Related Nodes
- [[QuickShell Event-Driven IPC]]
- [[TopBar & Dynamic Workspaces]]
- [[Native PipeWire 10-Band Equalizer]]
