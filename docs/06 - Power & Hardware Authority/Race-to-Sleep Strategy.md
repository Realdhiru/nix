---
title: Race-to-Sleep Strategy
tags: [power, battery, intel, c-states, hardware-physics, efficiency]
---

# Race-to-Sleep Strategy: The Physics of CPU Power Consumption

A common misconception among Linux users is that maximizing laptop battery life requires:
1. Disabling Intel Turbo Boost.
2. Setting the CPU governor to `powersave` or `power`.
3. Capping maximum operating frequencies at low thresholds (e.g. 1.2 GHz).

On modern Intel Core architectures (such as our 13th Gen Intel Core i5-13500H), **this practice actively degrades battery efficiency**.

---

## 1. The Physics of Package C-States

Total processor energy consumption consists of two distinct components:
1. **Dynamic Switching Power ($P = C \cdot V^2 \cdot f$)**: Energy consumed while actively flipping transistor states to compute instructions.
2. **Static Leakage Power**: Baseline energy consumed to keep the CPU core energized and unhalted ($C0$ state).

When an interactive task occurs (rendering a webpage, compiling a derivation, or switching workspaces):

### Case A: Artificially Throttled (1.2 GHz Fixed Cap)
- Clock speeds are clamped low.
- The task requires **800 milliseconds** of active CPU execution time.
- The processor package is trapped in active $C0$ power state for nearly a full second, consuming 8W–12W continuously.
- **Total Energy Consumed**: $\sim 8.0\text{ Joules}$.

### Case B: Race-to-Sleep (Burst at 4.2 GHz Turbo)
- Intel Turbo Boost allows performance cores to burst at full frequency.
- The task completes in **90 milliseconds**.
- The processor package immediately transitions back into deep hardware sleep states ($C8$ / $C10$), where package power drops below **0.5W**.
- **Total Energy Consumed**: $(25\text{W} \times 0.09\text{s}) + (0.5\text{W} \times 0.71\text{s}) = \mathbf{2.6\text{ Joules}}$.

---

## 2. Practical Outcome

By allowing the CPU to burst at full clock speeds and return immediately to sleep:
- Total battery energy consumption is reduced by nearly **3x**.
- Desktop compositing, animation framerates, and terminal responsiveness remain locked at a fluid 120 FPS without sluggishness.

## Related Nodes
- [[TLP Exclusive Authority]]
- [[ASUS Hardware Quirks]]
- [[Host Configuration Anatomy]]
