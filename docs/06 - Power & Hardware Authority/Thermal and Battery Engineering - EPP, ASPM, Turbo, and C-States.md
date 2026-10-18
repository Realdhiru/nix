---
title: Thermal and Battery Engineering - EPP, ASPM, Turbo, and C-States
tags: [power, battery, intel, tlp, aspm, epp, c-states, hardware-engineering]
---

# Thermal and Battery Engineering: EPP, ASPM, Turbo, and C-States

On modern multi-core mobile processors (our Intel Core i5-13500H with 4 Performance cores and 8 Efficient cores), power management cannot be simplified to "low clocks = good battery".

This document provides a deep-dive analysis of hardware power domains, PCIe link power states, Energy Performance Preferences (EPP), and the engineering choices that allow this desktop to idle under ~11W on battery while delivering 120Hz responsiveness.

---

## 1. Hardware Power Domains and Intel P-State

Modern Intel CPUs manage frequency scaling through the in-kernel **Intel P-State driver** (`intel_pstate`). Traditional Linux governors (like `ondemand` or `conservative`) are deprecated on modern hardware.

### Energy Performance Preference (EPP)
Under Intel P-State, the operating system no longer sets raw CPU clock speeds. Instead, it hints to the hardware's internal power management microcontroller (Intel Speed Shift) via the **Energy Performance Preference (EPP)** register:

- `performance`: Hardware aggressively ramps up clocks to maximum turbo at the slightest workload.
- `balance_performance`: Hardware ramps up quickly to complete work, but lowers voltage immediately when load drops.
- `balance_power`: Hardware hesitates to boost, favoring slower clock speeds.
- `power`: Hardware aggressively caps frequencies and disables high-voltage states.

### The EBUSY Trap
A classic Linux hardware trap occurs when modifying EPP via `/sys/devices/system/cpu/cpu*/power/energy_perf_bias`:
- If the CPU scaling governor is set to `performance`, the hardware refuses EPP modifications and returns `EBUSY (Device or resource busy)`.
- **Mitigation**: Our power management scripts always ensure the governor is set to `powersave` before applying granular EPP biases (`set_epp.sh`).

---

## 2. PCIe Active State Power Management (ASPM)

A major source of phantom battery drain on modern laptops is the **PCIe bus**. 
- Even if the CPU is asleep, PCIe lanes connecting the SSD, Wi-Fi card, and Thunderbolt controllers can remain in active high-power states ($L0$), drawing 2W–4W continuously.

### The Power Invariant: `powersupersave`
In `modules/system/power.nix`:
```ini
PCIE_ASPM_ON_BAT = "powersupersave"
```
This forces all compatible PCIe links into $L1$ and $L1$ sub-states ($L1.1$ / $L1.2$), cutting bus power draw to near zero milliwatts when peripherals are idle.

### The Thunderbolt 4 D3cold Trap
During testing, we discovered that allowing aggressive runtime power management on Intel Thunderbolt 4 root controllers (`00:0d.0` and `00:0d.3`) caused external USB hubs and Type-C drives to randomly disconnect after sleep, emitting `xhci_hcd: xHC error in resume, USBSTS 0x401`.
- **Mitigation**: We denylisted the Thunderbolt 4 controllers in TLP (`RUNTIME_PM_DENYLIST`), preventing them from cycling into broken $D3\text{cold}$ power states while keeping standard ASPM active across the rest of the PCIe tree.

---

## 3. Intel Framebuffer Compression (FBC) and OLED Power

Our laptop features an ASUS 2.8K 120Hz OLED display ($2880 \times 1800$). Driving this display requires massive data throughput:

$$\text{Data Rate} = 2880 \times 1800 \times 4\text{ bytes/pixel} \times 120\text{ Hz} \approx \mathbf{2.48\text{ GB/second}}$$

Constantly reading 2.5 GB of pixel data every second from system RAM over the memory bus prevents memory controllers from entering low-power self-refresh states.

### The Solution: `i915.enable_fbc=1`
We enabled Intel Framebuffer Compression via kernel parameters:
- The GPU hardware automatically compresses the desktop framebuffer in memory when the screen is static or partially updated.
- Bandwidth draw over the memory bus drops by **~70%**, saving up to **1.5W to 2.2W** of power during reading and coding.

---

## 4. Synthesis: Our Hardware Battery Profile

| Subsystem | Setting on Battery | Technical Rationale |
| :--- | :--- | :--- |
| **Platform Profile** | `balanced` | Avoids fan throttling and firmware power limits while preventing high wattage. |
| **EPP** | `balance_performance` | Enables Race-to-Sleep; instructions complete fast, allowing deep C-states. |
| **Turbo Boost** | `1` (Enabled) | Required for rapid task completion; throttling causes active C0 time ballooning. |
| **PCIe ASPM** | `powersupersave` | Drops idle bus links to L1 sub-states. |
| **GPU FBC** | `1` (Enabled) | Compresses 2.8K 120Hz framebuffer; saves ~2.2 GB/s memory bandwidth. |
| **Display Background** | Pure `#000000` | True black on OLED shuts off individual pixels, dropping panel draw to 0 mA. |

## Related Nodes
- [[Race-to-Sleep Strategy]]
- [[TLP Exclusive Authority]]
- [[ASUS Hardware Quirks]]
- [[Host Configuration Anatomy]]
