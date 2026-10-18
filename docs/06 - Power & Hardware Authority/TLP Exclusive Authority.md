---
title: TLP Exclusive Authority
tags: [power, tlp, asus, hardware, battery, governance]
---

# TLP Exclusive Authority: Single Source of Truth for Power

Power management on Linux laptops frequently suffers from daemon conflicts:
- `power-profiles-daemon` attempts to control ACPI platform profiles.
- Manufacturer daemons (like `asusd`) attempt to throttle CPU clocks and adjust fan profiles.
- Desktop environments attempt to manage sleep and screen dimming timers.

In `modules/system/power.nix`, we established **TLP 1.9.1 as the sole, authoritative hardware power governor**.

---

## 1. Deconflicting the Power Architecture

To eliminate conflicting hardware instructions, competing daemons are either disabled or strictly constrained:

- **`power-profiles-daemon`**: Completely masked and disabled.
- **`asusd`**: Stripped of power profile switching authority. In `asusd.ron`, `change_platform_profile_on_battery` and `change_platform_profile_on_ac` are locked to `false`. `asusd.service` is enabled strictly to enforce the **80% battery charge ceiling** (`charge_control_end_threshold = 80`).
- **TLP 1.9.1**: Exclusively manages CPU scaling governors, Energy Performance Preferences (EPP), Intel Turbo Boost, and PCIe Active State Power Management (ASPM).

---

## 2. Locked Balanced Battery Profile

Our empirically validated balanced profile is declared as follows:

```ini
# Battery power configuration:
PLATFORM_PROFILE_ON_BAT = "balanced"
CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_performance"
CPU_BOOST_ON_BAT = 1
PCIE_ASPM_ON_BAT = "powersupersave"
```

### Rationale for `balance_performance` on Battery
Rather than crippling CPU clocks to artificial limits (which increases time-to-completion and drains battery), `balance_performance` combined with Turbo Boost allows the CPU to finish tasks rapidly and return immediately to deep C-state sleep.

## Related Nodes
- [[Race-to-Sleep Strategy]]
- [[ASUS Hardware Quirks]]
- [[Coffee Mode]]
