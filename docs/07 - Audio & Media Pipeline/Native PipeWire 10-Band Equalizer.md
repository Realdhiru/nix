---
title: Native PipeWire 10-Band Equalizer
tags: [audio, pipewire, equalizer, dsp, performance, easyeffects]
---

# Native PipeWire 10-Band Equalizer: Decommissioning EasyEffects

For years, Linux desktop users seeking system-wide audio equalization installed **EasyEffects** (formerly PulseEffects).

In this system, EasyEffects was permanently removed. This document details why it was decommissioned and how PipeWire's native DSP filter-chain replaces it.

---

## 1. Why EasyEffects Was Decommissioned

EasyEffects introduces substantial overhead on mobile laptops:
- **High Memory Footprint**: Consumes ~150MB of resident RAM and 46MB of swap.
- **Thread Sprawl**: Spawns 19 background worker threads.
- **Fragile Preset Automation**: Loading presets from shell scripts requires brittle `sleep` commands and invokes Python JSON processors in hot paths.
- **Continuous CPU Wakeups**: Maintains active worker loops even when no audio applications are outputting sound.

---

## 2. The Native PipeWire Filter-Chain Solution

PipeWire includes an in-tree C digital signal processing module: `libpipewire-module-filter-chain`.

In `home.nix` (`~/.config/pipewire/pipewire.conf.d/99-equalizer-sink.conf`), we declared a native 10-band peaking biquad equalizer ($31\text{Hz}$ to $16\text{kHz}$ with $Q = 1.414$) running directly inside PipeWire's C audio loop:

```
[Applications] 
      │ (Default Audio Sink)
      ▼
[effect_input.eq10] ──▶ (10-Band Biquad Filter Chain) ──▶ [effect_output.eq10]
                                                                  │
                                                     (WirePlumber Auto-Routing)
                                                                  ▼
                                                      [Active Output Device]
```

### Key Architectural Advantages
1. **Zero Additional Resident Memory**: Runs directly inside the PipeWire daemon process already resident in memory.
2. **Sub-Millisecond Parameter Updates**: Adjusting equalizer sliders in QuickShell writes directly via POSIX commands in **2–4ms**:
   ```bash
   pw-cli s <id> Props '{ "params": [ "eq_band_0:Gain", 3.5 ] }'
   ```
   Python was completely purged from the audio hot path.
3. **Seamless Device Handover**: The virtual capture sink is assigned driver priority 2100. When Bluetooth headphones connect or disconnect, WirePlumber automatically re-routes the output stream without interrupting playback.

## Related Nodes
- [[MPV MPRIS Pipeline]]
- [[Widgets Breakdown]]
- [[Python Ban in Interactive Paths]]
