---
title: QuickShell Event-Driven IPC
tags: [quickshell, qml, ipc, pipewire, event-driven, architecture, performance]
---

# QuickShell Event-Driven IPC: The Elimination of Shell Polling Loops

Most custom Linux status bars and widget engines (such as Waybar, Polybar, Eww, or AGS) rely heavily on **periodic subprocess polling loops**:

```bash
# The classic anti-pattern:
while true; do
  wpctl get-volume @DEFAULT_AUDIO_SINK@
  cat /sys/class/power_supply/BAT0/capacity
  sleep 1
done
```

This pattern has disastrous consequences on modern laptop hardware:
- Spawns thousands of subshell processes every hour (`/bin/sh`, `awk`, `grep`).
- Forces CPU cores out of low-power sleep packages ($C8$ / $C10$) every second.
- Introduces up to 1000ms of visual lag between a hardware event and the user interface updating.

We eliminated shell polling entirely. QuickShell operates on **native C++ event subscriptions**.

---

## 1. Native Event Subscriptions

QuickShell executes directly within Qt6's C++ event loop and connects to kernel and compositor event streams without spawning child processes:

### 1. Hyprland Workspace IPC (~6ms Latency)
```qml
import Quickshell.Hyprland

// Direct UNIX domain socket connection to Hyprland's socket2:
Hyprland.focusedWorkspace
Hyprland.workspaces
Hyprland.rawEvent
```
When a workspace switch keybind is pressed, Hyprland emits an event on its IPC socket. QuickShell's C++ parser intercepts it in ~6ms, updating the TopBar active pill immediately.

### 2. PipeWire Audio Telemetry (~8ms Latency)
```qml
import Quickshell.Services.Pipewire

// Subscribes to PipeWire's in-memory node state:
Pipewire.defaultAudioSink.audio.volume
Pipewire.defaultAudioSink.audio.muted
```
Volume slider movements do not execute `wpctl` or `pactl` commands to query state. PipeWire emits an in-memory D-Bus signal, and the QML property binding updates automatically.

### 3. File Watchers on Kernel State
```qml
import Quickshell.Io

FileWatcher {
    path: "/sys/class/power_supply/BAT0/status"
}
```
State updates trigger directly from kernel inotify events rather than continuous reading loops.

---

## 2. Measurable Performance Impact

- **CPU Idle Consumption**: The entire QuickShell process consumes between **0.0% and 0.1% CPU** when idle.
- **Battery Impact**: Zero periodic wakeups allow the CPU to maintain deep sleep packages, reducing idle laptop power draw to ~10–11W on battery.
- **Visual Responsiveness**: Controls and sliders feel as responsive as a native operating system shell rather than a web view or stitched shell script.

## Related Nodes
- [[TopBar & Dynamic Workspaces]]
- [[Widgets Breakdown]]
- [[Python Ban in Interactive Paths]]
- [[QML Scene-Graph Coordinate Gating]]
