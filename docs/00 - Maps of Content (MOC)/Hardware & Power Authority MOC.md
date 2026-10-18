---
title: Hardware & Power Authority Map of Content
type: moc
tags: [moc, hardware, power, tlp, asus, index]
---

# Hardware and Power Authority Map of Content

Hardware governance, power arbitration, thermal management, and battery conservation for the ASUS Vivobook S 15 OLED (Intel Core i5-13500H).

---

## Core Documents

1. [[TLP Exclusive Authority]]
   - TLP 1.9.1 as the sole power governor.
   - Deconflicting competing daemons (`power-profiles-daemon` masked, `asusd` restricted).
   - Empirically locked balanced profile settings.

2. [[Race-to-Sleep Strategy]]
   - Package C-states physics ($C0$ vs $C8$/$C10$).
   - Why CPU clock throttling drains 3x more battery than high-frequency bursting.

3. [[Thermal and Battery Engineering - EPP, ASPM, Turbo, and C-States]]
   - Deep dive into Intel P-State hardware registers and Energy Performance Preferences (EPP).
   - PCIe bus link power management via ASPM (`powersupersave`) and the Thunderbolt 4 D3cold trap.
   - Framebuffer compression (`i915.enable_fbc=1`) saving ~2.2 GB/s memory bandwidth on 2.8K OLED.

4. [[ASUS Hardware Quirks]]
   - Firmware 80% charge ceiling.
   - Post-hibernate OLED brightness Fn keys driver rebind hook.
   - Lid switch ignore policy in systemd logind.

5. [[Coffee Mode]]
   - Native systemd idle inhibitor state machine (`power.sh inhibit`).
   - Canonical state persistence in `~/.cache/quickshell/state.json`.

## Related Domains
- [[QuickShell Desktop MOC]]
- [[System Architecture MOC]]
