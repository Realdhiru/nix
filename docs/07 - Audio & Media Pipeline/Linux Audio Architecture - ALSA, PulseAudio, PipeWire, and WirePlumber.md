---
title: Linux Audio Architecture - ALSA, PulseAudio, PipeWire, and WirePlumber
tags: [audio, linux, pipewire, alsa, pulseaudio, wireplumber, dsp, architecture]
---

# Linux Audio Architecture: The Evolution from ALSA to Native PipeWire DSP

Understanding audio on modern Linux requires unravelling 25 years of audio server evolution. New developers often get confused by the coexistence of ALSA, PulseAudio, JACK, PipeWire, and WirePlumber.

This document breaks down the layered hierarchy of the Linux audio stack, why PipeWire won, and how our system operates without PulseAudio or EasyEffects.

---

## 1. The Historical Layers of Linux Audio

```
┌────────────────────────────────────────────────────────┐
│ Applications (Chromium, Spotify, Games, MPV, DAW)      │
└───────────┬─────────────────────────┬──────────────────┘
            │ (PulseAudio API)        │ (JACK API / ALSA API)
            ▼                         ▼
┌────────────────────────────────────────────────────────┐
│ PipeWire Daemon (Single unified C multimedia graph)    │
│  ├─ Emulates libpulse.so (PulseAudio compatibility)    │
│  ├─ Emulates libjack.so (Pro-audio low-latency)        │
│  └─ Executes in-process DSP (Filter-Chain Equalizer)   │
└───────────────────────────┬────────────────────────────┘
                            │ (D-Bus / Socket)
                            ▼
┌────────────────────────────────────────────────────────┐
│ WirePlumber (Session Manager & Policy Engine)          │
│  ├─ Device discovery & priority autoswitch             │
│  └─ Endpoint volume state persistence                  │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ ALSA Kernel Drivers (Advanced Linux Sound Architecture)│
│  └─ Physical hardware access: Intel HDA / USB DAC      │
└────────────────────────────────────────────────────────┘
```

### Layer 1: ALSA (Kernel Driver Level)
- **Role**: Communicates directly with PCI, USB, and SoC sound cards.
- **Limitation**: Historical ALSA could only be opened by one application at a time. If game audio opened `/dev/snd/pcmC0D0p`, your browser could not play sound.

### Layer 2: PulseAudio (The Desktop Server - Legacy)
- **Role**: Created a software mixer daemon on top of ALSA so multiple desktop apps could share the audio device.
- **Limitation**: High latency (20ms–50ms), poor buffer scheduling for professional audio/DAWs, and rigid monolithic code.

### Layer 3: JACK (The Pro-Audio Server - Legacy)
- **Role**: Ultra-low-latency synchronous audio graph for music production.
- **Limitation**: Impractical for general desktop use; fought with PulseAudio over ALSA device locks.

---

## 2. The PipeWire Revolution

**PipeWire** replaced both PulseAudio and JACK with a single, modern C multimedia graph:
- **Unified Graph**: Applications talk to PipeWire using whatever API they were written for (PulseAudio, JACK, ALSA). PipeWire presents virtual compatibility layers (`pipewire-pulse`) that trick legacy applications into believing PulseAudio is running.
- **Zero-Copy Processing**: Uses Linux shared memory (`memfd_create`) and DMA-BUF to pass audio buffers between applications and the kernel with sub-millisecond latency.
- **Dynamic Buffer Sizes**: Runs at standard power-saving buffer sizes during video playback, but drops automatically to low-latency buffers (e.g. 64/128 samples) when a low-latency audio client requests it.

---

## 3. WirePlumber: The Policy Engine

PipeWire itself is intentionally dumb: it only routes audio buffers across connected nodes. It does not decide which speaker to use, when to switch to Bluetooth, or what volume to apply.

That policy belongs to **WirePlumber**:
- In our system, WirePlumber executes rules defined in `home.nix`:
  - `50-disable-libcamera.conf`: Disables conflicting libcamera UVC video monitors.
  - `51-device-autoswitch.conf`: Assigns priority scores to physical devices (Bluetooth DAC > USB DAC > Internal Speakers).

---

## 4. Why We Chose Native Filter-Chain Over EasyEffects

| Dimension | EasyEffects (Daemon) | PipeWire `filter-chain` (Our Setup) |
| :--- | :--- | :--- |
| **Execution Context** | Standalone GTK/Rust user process | In-process C module inside PipeWire data-loop |
| **Memory Overhead** | ~150MB RSS + 46MB Swap | **0MB additional memory** |
| **Worker Threads** | 19 background threads | **0 extra threads** (runs on existing audio loop) |
| **Parameter Latency** | Slow Python/D-Bus preset loading | **2–4ms via direct `pw-cli` calls** |
| **Crash Resilience** | If daemon dies, audio drops or unlinks | In-tree module; indestructible unless PipeWire restarts |

## Related Nodes
- [[Native PipeWire 10-Band Equalizer]]
- [[MPV MPRIS Pipeline]]
- [[Widgets Breakdown]]
