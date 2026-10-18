---
title: Audio & Media Pipeline Map of Content
type: moc
tags: [moc, audio, media, pipewire, index]
---

# Audio and Media Pipeline Map of Content

Low-latency audio routing, DSP equalization, and media player telemetry.

---

## Core Documents

1. [[Linux Audio Architecture - ALSA, PulseAudio, PipeWire, and WirePlumber]]
   - The 25-year evolution of the Linux audio stack.
   - PipeWire as a unified multimedia graph replacing PulseAudio and JACK.
   - WirePlumber session policies and device priority autoswitching.

2. [[Native PipeWire 10-Band Equalizer]]
   - Decommissioning EasyEffects (saving ~150MB RAM and 19 worker threads).
   - In-tree C DSP biquad filter chain ($Q = 1.414$).
   - Sub-millisecond gain adjustments via direct `pw-cli` calls.

3. [[MPV MPRIS Pipeline]]
   - Declarative C plugin compilation for MPV media playback tracking.
   - Preventing garbage collection deletion of store plugins via declarative Home Manager symlinks.

4. [[Hardware Video Acceleration & Web Apps]]
   - Native Intel VA-API decoding and zero-copy surface presentation across Brave, PWAs, and web apps.
   - Bypassing Nixpkgs wrapper omission and eliminating 4K 60/120fps video glitching.

## Related Domains
- [[QuickShell Desktop MOC]]
- [[System Architecture MOC]]
