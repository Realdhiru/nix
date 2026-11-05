# Audio Engineering & DSP Architecture Master Reference

Comprehensive architectural documentation covering the PipeWire DSP filter graph, dynamic output device routing, spectral karaoke center cancellation, and acoustic equalizer presets.

---

## 1. System Audio Graph Architecture

The desktop audio architecture routes all client audio through a unified virtual sink:

```
[Applications (Brave, Spotify, MPV, Games)]
                     │
                     ▼
             [effect_input.eq10]  (PipeWire Audio/Sink, priority 2500)
                     │
          ┌──────────┴──────────┐
          │                     │
     [Dry Path]            [Wet Path]
    (21.33ms delay)   (Native C spectral_karaoke)
          │                     │
          └──────────┬──────────┘
                     ▼
          [finalL / finalR Mixers]  (Gain 1: Dry, Gain 2: Wet)
                     │
                     ▼
       [10-Band Biquad Stereo Peaking Filters]
         31Hz, 63Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
                     │
                     ▼
       [Lookahead Limiter (-0.2 dB ceiling, 0.10s release)]
                     │
                     ▼
            [effect_output.eq10]  (PipeWire Stream/Output/Audio, passive)
                     │
       ┌─────────────┼─────────────┐
       ▼             ▼             ▼
  [Bluetooth]   [Headphones]   [Laptop Speaker]
 (e.g. Earbuds)  (3.5mm Jack)   (Realtek ALC294)
```

---

## 2. Issues Encountered, Root Causes & Technical Resolutions

### Issue 1: Hardcoded "Wired Headphones" in Output Notifications & Widget
* **Problem**: When switching output devices with Bluetooth earbuds connected (e.g. OnePlus Nord Buds 3), the system toast and music widget displayed "Wired Headphones" or cycled to the inactive ALC294 headphone profile.
* **Root Cause**:
  1. `music_info.sh` had fallback patterns hardcoding `dev_name="Wired Headphones"` whenever the sink name contained `Headphone` or `headset`, ignoring the actual PipeWire node description (`node.description`).
  2. `cycle_audio_sink.sh` had a hardcoded decision tree that assumed any non-speaker internal state was `Wired Headphones`, without checking whether the physical 3.5mm headphone jack was actually plugged in (`[Out] Headphones .available == "yes"`).
* **Fix**:
  - `music_info.sh`: Replaced static string overrides with dynamic PipeWire `node.description` and `node.nick` lookups. If connected to earbuds, it directly queries and emits the real device name (e.g., `OnePlus Nord Buds 3`).
  - `cycle_audio_sink.sh`: Added physical jack availability detection via `pw-dump Device` route inspection. If wired headphones are unplugged, it skips the 3.5mm profile and directly routes to connected Bluetooth/USB sinks.

---

### Issue 2: Lead Vocal Removal vs Side Harmonies & Uncompressed Instrumental Dynamics
* **User Requirement & Target**:
  1. **Dead-Center Lead Vocal & Crowd Elimination**: Lead singer, spoken vocals, and center noise must be completely removed (`Depth = 0.99`, `Low Cutoff = 100 Hz`).
  2. **Harmonies & Instruments Preserved**: Stereo backing harmonies (panned left/right), electric/acoustic guitars, synths, and flutes must remain 100% audible and untouched.
  3. **Zero Digital Pumping / Sidechain Squeezing**: Completely eliminate side reverb ducking (`Reverb Duck = 0.0 dB`) and transient suppression (`Transient Protection = 0.0`) so instruments sound free, open, and naturally live.
* **Root Causes**:
  1. Setting `Reverb Duck = 4.0 dB` artificially ducked side channels by 4 dB whenever center energy hit, which squashed stereo instruments and backing harmonies, giving a cold, compressed, digital feeling.
  2. When `Low Cutoff` was previously tested at 200 Hz, male vocal fundamentals (120–180 Hz) escaped cancellation and bled through.
* **Final Engineered Fix**:
  - `Low Cutoff` tuned to **100 Hz**: Deeply cuts all lead vocal formants and speech, while granting immunity to sub-bass fundamentals (< 100 Hz).
  - `Depth` set to **0.99** with **0.05** Air Depth: Deep vocal elimination without harsh treble remnants.
  - `Reverb Duck` set to **0.0 dB** and `Transient Protection` to **0.0**: Eliminates all side-channel compression; stereo instruments and wide harmonies breathe freely with full live stage acoustics.

---

### Issue 3: Electric Guitar Harmonic Attenuation in Karaoke Mode
* **Problem**: Electric guitars were getting cut or thinned out along with center vocals.
* **Root Cause**: The phase correlation formula had a wide detection cone ($m = \psi^4$), and the vocal cancellation band extended up into 10 kHz. Distorted electric guitars with wide stereo imaging and high mid-frequency energy were partially matched as center vocals.
* **Fix**:
  - Sharpened the phase isolation formula from $\psi^4$ to $\psi^8$ in `spectral_karaoke.c`. Only signals dead-center in the stereo field are suppressed.
  - Rolled off vocal cancellation above 4.2 kHz (the upper limit of vocal formants). Electric guitar harmonics, pick attack, and bite remain completely untouched.

---

### Issue 4: Speaker Audio Leak Burst on Unplug
* **Problem**: When unplugging headphones while audio played, a split-second burst of sound leaked through the laptop speaker before pausing.
* **Root Cause**: PipeWire ALSA sink nodes default to `node.drain-on-empty = true`. When the stream rerouted, the speaker driver flushed the remaining audio frames stored in the hardware ring buffer.
* **Fix**:
  - In `home.nix` under `monitor.alsa.rules`, added `node.drain-on-empty = false` and `session.suspend-timeout-seconds = 0` to `~alsa_output.*Speaker.*`. Hardware buffers drop instantly upon disconnect.

---

### Issue 5: Silent Fallback After Device Disconnect
* **Problem**: When unplugging headphones or disconnecting Bluetooth, resuming playback resulted in silence.
* **Root Cause**: WirePlumber had `device.routes.mute-on-alsa-playback-removed = true` and `mute-on-bluetooth-playback-removed = true`, which auto-muted the laptop speaker on disconnect.
* **Fix**:
  - Set both properties to `false` in `wireplumber.settings` in `home.nix`. Disconnecting an external device safely switches to the speaker with full volume unmuted.

---

### Issue 6: Arrow Keys Stealing Media Timeline Focus
* **Problem**: Pressing left/right arrow keys in `MusicPopup.qml` jumped the song timeline instead of switching equalizer presets.
* **Root Cause**: The `Slider` components (`progBar` and `eqSlider`) captured active focus upon click or interaction, intercepting `Qt.Key_Left` and `Qt.Key_Right`.
* **Fix**:
  - Added `focusPolicy: Qt.NoFocus` to `progBar` and `eqSlider`.
  - Added `root.forceActiveFocus()` on `onVisibleChanged`. Arrow keys now cleanly and reliably cycle equalizer presets.

---

## 3. Complete Preset Engineering & Acoustic Curves

All system presets are engineered with precise decibel targets across the 10-band biquad peaking equalizer ($Q = 1.414$) to achieve their specific sonic targets:

| Band | Frequency | **Bass** (Concert) | **Karaoke** (Detail) | **Vocal** (Live Stage) | **Rock** (Punch) | **Pop** (Vibrant) | **Jazz** (Warm) | **Classic** (Hall) | **Treble** (Air) |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **B1** | 31 Hz | **+5 dB** | **+3 dB** | **-1 dB** | **+4 dB** | **+3 dB** | **+2 dB** | **+3 dB** | **-3 dB** |
| **B2** | 63 Hz | **+7 dB** | **+3 dB** | **0 dB** | **+4 dB** | **+4 dB** | **+3 dB** | **+3 dB** | **-2 dB** |
| **B3** | 125 Hz | **+4 dB** | **+2 dB** | **+1 dB** | **+3 dB** | **+3 dB** | **+3 dB** | **+2 dB** | **-1 dB** |
| **B4** | 250 Hz | **0 dB** | **+1 dB** | **+3 dB** | **0 dB** | **-1 dB** | **+2 dB** | **0 dB** | **0 dB** |
| **B5** | 500 Hz | **0 dB** | **-1 dB** | **+5 dB** | **-1 dB** | **-1 dB** | **+2 dB** | **0 dB** | **+1 dB** |
| **B6** | 1 kHz | **+1 dB** | **-2 dB** | **+4 dB** | **+1 dB** | **+1 dB** | **+2 dB** | **+1 dB** | **+2 dB** |
| **B7** | 2 kHz | **+2 dB** | **0 dB** | **+3 dB** | **+3 dB** | **+3 dB** | **+1 dB** | **+2 dB** | **+4 dB** |
| **B8** | 4 kHz | **+2 dB** | **+2 dB** | **+2 dB** | **+4 dB** | **+4 dB** | **+2 dB** | **+3 dB** | **+5 dB** |
| **B9** | 8 kHz | **+2 dB** | **+3 dB** | **+2 dB** | **+4 dB** | **+3 dB** | **+3 dB** | **+4 dB** | **+6 dB** |
| **B10** | 16 kHz | **+1 dB** | **+3 dB** | **+1 dB** | **+3 dB** | **+2 dB** | **+2 dB** | **+3 dB** | **+5 dB** |

### Preset Acoustic Signatures:
1. **Bass Mode**: Designed for massive live concert feel without muddiness. Delivers deep sub-bass impact (+7 dB @ 63 Hz, +5 dB @ 31 Hz) while leaving mid frequencies clean (0 dB @ 250–500 Hz) and opening the top end (+2 dB @ 2–8 kHz) for venue ambiance.
2. **Karaoke Mode**: Designed for musicians learning instrumental parts and sing-alongs. Center vocals are cancelled via the LADSPA wet filter while hidden backing instruments, subtle arpeggios, and high-frequency textures are boosted (+2 to +3 dB from 4–16 kHz).
3. **Vocal Mode**: An open, raw, intimate stage performance curve. Cuts sub-bass (-1 dB @ 31 Hz) to prevent masking, while boosting chest warmth (+3 dB @ 250 Hz) and vocal presence (+5 dB @ 500 Hz, +4 dB @ 1 kHz).
4. **Rock Mode**: Aggressive V-curve with heavy kick/bass punch (+4 dB @ 31–63 Hz), tight mid scoop (-1 dB @ 500 Hz), and sharp electric guitar/cymbal crunch (+4 dB @ 4–8 kHz).
5. **Pop Mode**: Bright and radio-ready with lifted bass (+4 dB @ 63 Hz) and crisp, airy vocals (+4 dB @ 4 kHz).
6. **Jazz Mode**: Warm, velvety, rounded response with full lower mids (+2 to +3 dB across 125–1000 Hz) and rolled-off extremes.
7. **Classic Mode**: Simulates a symphonic concert hall with spacious lower octave warmth and high string sparkle (+4 dB @ 8 kHz).
8. **Treble Mode**: Analytical, ultra-bright presentation for speech intelligibility and high cymbal detail (+6 dB @ 8 kHz).

---

## 4. Complete System Audio Stack & Configuration Reference

### 4.1 Underlying Software Stack
- **Audio Server**: PipeWire (`0.3.x`) running as a low-latency multimedia routing framework.
- **Session Manager**: WirePlumber managing node endpoints, dynamic device routes, and ALSA profiles.
- **DSP Engine**: Native PipeWire `libpipewire-module-filter-chain` executing LADSPA and built-in biquad filters directly in real-time audio threads.
- **Karaoke DSP Plugin**: Custom C LADSPA plugin (`spectral_karaoke.so`, Unique ID `4899`) compiled with `-O3 -mavx2 -ffast-math`.
- **Master Speaker Protection**: Steve Harris LADSPA 1913 (`fast_lookahead_limiter_1913.so`) with -0.2 dB ceiling and 0.10s release.
- **Microphone Enhancement**: PipeWire `libpipewire-module-echo-cancel` with WebRTC AEC, AGC, and noise suppression (`60-echo-cancel.conf`).
- **Control Interface**:
  - `equalizer.sh`: IPC interface controlling PipeWire filter-chain node parameters via `pw-cli s <node_id> Props`.
  - `karaoke.sh`: Toggles mixer routing between dry path (`finalL:Gain 1 = 1.0, Gain 2 = 0.0`) and wet karaoke path (`finalL:Gain 1 = 0.0, Gain 2 = 1.0`).
  - `MusicPopup.qml`: QuickShell QML user interface featuring animated biquad EQ sliders, glowing multi-band canvas lightning effects, optimistic UI updates, and keyboard shortcuts (`Left`/`Right` arrow keys to cycle presets).

### 4.2 Why this Stack was Chosen (vs Alternatives)
- **Why Native PipeWire Filter-Chain instead of EasyEffects?**
  EasyEffects is a heavy GTK/Rust application that runs a separate persistent daemon, consumes significant RAM (150MB+), and introduces IPC delay and occasional crashes during PipeWire stream switches. The native PipeWire filter chain runs directly inside PipeWire's processing thread with 0 additional processes, 0 MB extra RSS, and microsecond latency.
- **Why Custom LADSPA C Plugin instead of Mid-Side Inversion?**
  Basic mid-side ($L - R$) cancellation destroys all center information including mono bass, kick drums, and centered guitar solos, resulting in a thin, hollow, phase-cancelled mess. Our spectral LADSPA plugin operates in the frequency domain with STFT (1024-point FFT), isolating center vocals by phase correlation ($m = \psi^8$) only between 200 Hz and 4.2 kHz, leaving all stereo instruments, bass, and kick drums 100% untouched.
- **Why Built-in Biquad Filters instead of External Graphic EQ?**
  PipeWire's built-in `bq_peaking` filters run with zero external library overhead and zero memory allocation. Gain changes can be updated atomically on the fly via `pw-cli` without interrupting or clicking audio playback.
