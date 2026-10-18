---
title: ASUS Hardware Quirks
tags: [hardware, asus, quirks, udev, battery-ceiling, acpi]
---

# ASUS Hardware Quirks: Non-Obvious Hardware Invariants

Running Linux on modern ASUS hardware (specifically the ASUS Vivobook S 15 OLED K5504VA / S5504VA) exposes specific hardware traps that required custom kernel parameters and udev engineering.

---

## 1. The 80% Battery Charge Ceiling

Lithium-ion cells degrade rapidly when maintained at 100% state-of-charge under high operating temperatures.
- **Implementation**: Enforced via `asusd.ron` with `charge_control_end_threshold = 80`.
- **Behavior**: Once the battery reaches 80%, the internal charge controller halts charging and switches power delivery to direct motherboard passthrough, extending battery cycle life significantly.

---

## 2. OLED Brightness Fn Keys Unresponsive Post-Hibernate

- **The Issue**: Following a resume from hybrid-sleep or deep sleep, the physical brightness hotkeys (`F7`/`F8`) cease sending ACPI key events to the desktop environment.
- **The Root Cause**: The kernel auxiliary video bus driver (`acpi.video_bus.0`) enters an uninitialized state during sleep transitions.
- **The Solution**: In `hosts/nixos/hardware/asus.nix`, a systemd post-resume hook unbinds and rebinds the driver automatically:
  ```bash
  echo acpi.video_bus.0 > /sys/bus/auxiliary/drivers/video/unbind
  echo acpi.video_bus.0 > /sys/bus/auxiliary/drivers/video/bind
  ```
  Brightness hotkeys recover immediately without requiring a machine reboot.

---

## 3. Lid Switch Policy: Ignoring Lid Close

- Standard laptop defaults trigger automatic sleep when the lid is closed.
- In modern developer workflows, laptops are frequently closed while compiling long builds, streaming audio over Bluetooth, or running background compute jobs.
- **Configuration**: `HandleLidSwitch = "ignore"` in systemd logind. Suspend is strictly deliberate via keybind (`Shift + Esc`) or automated 30-minute idle sleep.

## Related Nodes
- [[TLP Exclusive Authority]]
- [[Race-to-Sleep Strategy]]
- [[Coffee Mode]]
