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

### Issue 2: Instrument & Bass Compression in Karaoke Mode
* **Problem**: When Karaoke mode was engaged, acoustic instruments (flute, guitar, bass, kick drums) sounded compressed, squeezed, and choked.
* **Root Causes**:
  1. **Broadband Transient Pumping**: `spectral_karaoke.c` calculated broadband spectral flux on the mid channel. Whenever a transient hit (kick, snare, guitar strum), `trans_scale` throttled gain across the *entire spectrum*, acting like an aggressive sidechain compressor.
  2. **Low-End Interference**: The low-cutoff filter was set to 160 Hz with a wide transition window down to 128 Hz, allowing bass fundamentals and kick drum sustain to trigger center attenuation.
  3. **Master Limiter Squashing**: The lookahead limiter was configured with `Limit = -1.0 dB` and a slow `Release = 0.50s`. Boosted EQ bands hit the limiter ceiling and remained pinned down for 500ms.
* **Fix**:
  - Completely removed the broadband flux detector from `spectral_karaoke.c`. Center attenuation operates purely per-bin based on phase correlation ($m = \psi^8$), with zero dynamic envelope pumping.
  - Raised `Low Cutoff` to **200 Hz** with a tight transition (`170 Hz`). All sub-bass, bass guitar notes, and kick drums are 100% immune from the karaoke filter.
  - Relaxed the limiter in `home.nix` to a transparent `-0.2 dB` ceiling with a fast `0.10s` release.

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

## 3. Acoustic Equalizer Presets Engineering

All three core presets are engineered to provide an authentic **live concert / stage venue** atmosphere:

| Band | Frequency | **Bass** (Concert Arena) | **Karaoke** (Detail Revealing) | **Vocal** (Raw Live Stage) |
| :---: | :---: | :---: | :---: | :---: |
| **B1** | 31 Hz | **+5 dB** | **+3 dB** | **-1 dB** |
| **B2** | 63 Hz | **+7 dB** | **+3 dB** | **0 dB** |
| **B3** | 125 Hz | **+4 dB** | **+2 dB** | **+1 dB** |
| **B4** | 250 Hz | **0 dB** | **+1 dB** | **+3 dB** |
| **B5** | 500 Hz | **0 dB** | **-1 dB** | **+5 dB** |
| **B6** | 1 kHz | **+1 dB** | **-2 dB** | **+4 dB** |
| **B7** | 2 kHz | **+2 dB** | **0 dB** | **+3 dB** |
| **B8** | 4 kHz | **+2 dB** | **+2 dB** | **+2 dB** |
| **B9** | 8 kHz | **+2 dB** | **+3 dB** | **+2 dB** |
| **B10** | 16 kHz | **+1 dB** | **+3 dB** | **+1 dB** |

### Preset Characteristics:
1. **Bass Mode**: Replicates standing in front of festival line-array subwoofers. Deep, uncompressed low-end (`+7 dB @ 63 Hz`) with natural uncolored midrange (`0 dB @ 250–500 Hz`) and subtle venue acoustic air (`+2 dB @ 2–8 kHz`).
2. **Karaoke Mode**: Designed for musicians replicating band parts and sing-along. Center vocals are cleanly removed while buried backing details, arpeggios, and hi-hats are pulled forward (`+2 to +3 dB @ 4–16 kHz`).
3. **Vocal Mode**: Intimate, raw, live stage performance. Tones down deep sub-bass to create room for warm chest resonance (`+3 dB @ 250 Hz`) and vocal presence (`+5 dB @ 500 Hz, +4 dB @ 1 kHz`).
