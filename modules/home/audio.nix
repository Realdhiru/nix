{ pkgs, ... }:

{
  # WirePlumber: Prioritize external audio devices (Bluetooth, USB DAC/headsets, Headphones) over internal speaker
  xdg.configFile."wireplumber/wireplumber.conf.d/51-device-autoswitch.conf" = {
    force = true;
    text = ''
      monitor.bluez.rules = [
        {
          matches = [
            {
              device.name = "~bluez_card.*"
            }
          ]
          actions = {
            update-props = {
              "session.dont-restore-off-profile" = true
              "bluez5.auto-connect" = [ "a2dp_sink" ]
              "bluez5.hw-volume" = [ "a2dp_sink" ]
              "device.routes.default-sink-volume" = 1.0
            }
          }
        }
        {
          matches = [
            {
              node.name = "~bluez_output.*"
            }
          ]
          actions = {
            update-props = {
              priority.session = 2150
              priority.driver = 2150
            }
          }
        }
        {
          matches = [
            {
              node.name = "~bluez_input.*"
            }
          ]
          actions = {
            update-props = {
              priority.session = 2000
              priority.driver = 2000
            }
          }
        }
      ]

      monitor.alsa.rules = [
        {
          matches = [
            {
              device.name = "~alsa_card.*"
            }
          ]
          actions = {
            update-props = {
              "session.dont-restore-off-profile" = true
              "api.acp.auto-profile" = true
              "api.acp.auto-port" = true
            }
          }
        }
        {
          matches = [
            {
              node.name = "~alsa_output.*usb.*"
            }
          ]
          actions = {
            update-props = {
              priority.session = 2150
              priority.driver = 2150
            }
          }
        }
        {
          matches = [
            {
              node.name = "~alsa_output.*Headphones.*"
            }
          ]
          actions = {
            update-props = {
              priority.session = 2150
              priority.driver = 2150
            }
          }
        }
        {
          matches = [
            {
              node.name = "~alsa_output.*headset.*"
            }
          ]
          actions = {
            update-props = {
              priority.session = 2150
              priority.driver = 2150
            }
          }
        }
        {
          matches = [
            {
              node.name = "~alsa_output.*Speaker.*"
            }
          ]
          actions = {
            update-props = {
              priority.session = 1000
              priority.driver = 1000
              "node.drain-on-empty" = false
              "session.suspend-timeout-seconds" = 0
            }
          }
        }
        {
          matches = [
            {
              node.name = "~alsa_output.*HDMI.*"
            }
          ]
          actions = {
            update-props = {
              priority.session = 500
              priority.driver = 500
            }
          }
        }
        {
          matches = [
            {
              node.name = "~alsa_output.*"
            }
          ]
          actions = {
            update-props = {
              "api.alsa.disable-mmap" = true
              "api.alsa.headroom" = 1024
            }
          }
        }
      ]

      wireplumber.settings = {
        "linking.allow-moving-streams" = true
        "linking.follow-default-target" = true
        "device.restore-profile" = false
        "bluetooth.autoswitch-to-headset-profile" = false
        "bluetooth.profile-preference" = "quality"
        "bluetooth.use-persistent-storage" = false
        "device.routes.mute-on-bluetooth-playback-removed" = false
        "device.routes.mute-on-alsa-playback-removed" = false
        "device.routes.default-sink-volume" = 1.0
        "session.suspend-timeout-seconds" = 0
      }
    '';
  };

  # PipeWire: Quantum bounds to eliminate buffer underruns on Intel SOF DSP
  xdg.configFile."pipewire/pipewire.conf.d/10-quantum.conf" = {
    force = true;
    text = ''
      context.properties = {
          default.clock.min-quantum = 512
          default.clock.max-quantum = 2048
          default.clock.quantum = 1024
      }
    '';
  };
  # Native Unified 10-band Equalizer and Mid-Side Karaoke filter-chain for PipeWire
  xdg.configFile."pipewire/pipewire.conf.d/99-equalizer-sink.conf".text = ''
    context.modules = [
      { name = libpipewire-module-filter-chain
        args = {
          node.description = "PipeWire Equalizer"
          media.name       = "PipeWire Equalizer"
          filter.graph = {
            nodes = [
              { type = builtin label = copy name = inL }
              { type = builtin label = copy name = inR }

              # Dry path delay compensation to match spectral karaoke (1024 samples = 21.33ms)
              { type = builtin label = delay name = delayL
                config = { "max-delay" = 0.1 }
                control = { "Delay (s)" = 0.021333 } }
              { type = builtin label = delay name = delayR
                config = { "max-delay" = 0.1 }
                control = { "Delay (s)" = 0.021333 } }

              # Native C Spectral Per-Bin Karaoke LADSPA Plugin
              { type = ladspa
                name = spectral_karaoke
                plugin = "${pkgs.ladspa-spectral-karaoke}/lib/ladspa/spectral_karaoke.so"
                label = spectral_karaoke
                control = {
                  "Depth"                = 0.99
                  "Low Cutoff (Hz)"      = 100.0
                  "Air Depth"            = 0.05
                  "Transient Protection" = 0.0
                  "Release (ms)"         = 40.0
                  "Reverb Duck (dB)"     = 0.0
                }
              }

              # Fast Lookahead Limiter (Steve Harris SWH LADSPA 1913) - Master Output Speaker Protection
              { type = ladspa
                name = limiter
                plugin = "${pkgs.ladspaPlugins}/lib/ladspa/fast_lookahead_limiter_1913.so"
                label = fastLookaheadLimiter
                control = {
                  "Input gain (dB)"  = 0.0
                  "Limit (dB)"       = -0.2
                  "Release time (s)" = 0.10
                }
              }

              # Mode selector mixers: In 1 = dry, In 2 = wet karaoke
              { type = builtin label = mixer name = finalL control = { "Gain 1" = 1.0 "Gain 2" = 0.0 } }
              { type = builtin label = mixer name = finalR control = { "Gain 1" = 1.0 "Gain 2" = 0.0 } }

              # 10-Band Equalizer stages (Stereo left & right)
              { type = builtin name = eq_band_1_l  label = bq_peaking control = { "Freq" = 31.0   "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_2_l  label = bq_peaking control = { "Freq" = 63.0   "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_3_l  label = bq_peaking control = { "Freq" = 125.0  "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_4_l  label = bq_peaking control = { "Freq" = 250.0  "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_5_l  label = bq_peaking control = { "Freq" = 500.0  "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_6_l  label = bq_peaking control = { "Freq" = 1000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_7_l  label = bq_peaking control = { "Freq" = 2000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_8_l  label = bq_peaking control = { "Freq" = 4000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_9_l  label = bq_peaking control = { "Freq" = 8000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_10_l label = bq_peaking control = { "Freq" = 16000.0 "Q" = 1.414 "Gain" = 0.0 } }

              { type = builtin name = eq_band_1_r  label = bq_peaking control = { "Freq" = 31.0   "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_2_r  label = bq_peaking control = { "Freq" = 63.0   "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_3_r  label = bq_peaking control = { "Freq" = 125.0  "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_4_r  label = bq_peaking control = { "Freq" = 250.0  "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_5_r  label = bq_peaking control = { "Freq" = 500.0  "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_6_r  label = bq_peaking control = { "Freq" = 1000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_7_r  label = bq_peaking control = { "Freq" = 2000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_8_r  label = bq_peaking control = { "Freq" = 4000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_9_r  label = bq_peaking control = { "Freq" = 8000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_10_r label = bq_peaking control = { "Freq" = 16000.0 "Q" = 1.414 "Gain" = 0.0 } }
            ]
            links = [
              # Dry path to delay
              { output = "inL:Out" input = "delayL:In" }
              { output = "inR:Out" input = "delayR:In" }

              # Wet path through Spectral Karaoke plugin
              { output = "inL:Out" input = "spectral_karaoke:Input L" }
              { output = "inR:Out" input = "spectral_karaoke:Input R" }

              # Selectors: In 1 = delayed dry, In 2 = wet karaoke
              { output = "delayL:Out"                input = "finalL:In 1" }
              { output = "spectral_karaoke:Output L" input = "finalL:In 2" }
              { output = "delayR:Out"                input = "finalR:In 1" }
              { output = "spectral_karaoke:Output R" input = "finalR:In 2" }

              # Left Equalizer Chain
              { output = "finalL:Out"        input = "eq_band_1_l:In" }
              { output = "eq_band_1_l:Out"   input = "eq_band_2_l:In" }
              { output = "eq_band_2_l:Out"   input = "eq_band_3_l:In" }
              { output = "eq_band_3_l:Out"   input = "eq_band_4_l:In" }
              { output = "eq_band_4_l:Out"   input = "eq_band_5_l:In" }
              { output = "eq_band_5_l:Out"   input = "eq_band_6_l:In" }
              { output = "eq_band_6_l:Out"   input = "eq_band_7_l:In" }
              { output = "eq_band_7_l:Out"   input = "eq_band_8_l:In" }
              { output = "eq_band_8_l:Out"   input = "eq_band_9_l:In" }
              { output = "eq_band_9_l:Out"   input = "eq_band_10_l:In" }
              { output = "eq_band_10_l:Out"  input = "limiter:Input 1" }

              # Right Equalizer Chain
              { output = "finalR:Out"        input = "eq_band_1_r:In" }
              { output = "eq_band_1_r:Out"   input = "eq_band_2_r:In" }
              { output = "eq_band_2_r:Out"   input = "eq_band_3_r:In" }
              { output = "eq_band_3_r:Out"   input = "eq_band_4_r:In" }
              { output = "eq_band_4_r:Out"   input = "eq_band_5_r:In" }
              { output = "eq_band_5_r:Out"   input = "eq_band_6_r:In" }
              { output = "eq_band_6_r:Out"   input = "eq_band_7_r:In" }
              { output = "eq_band_7_r:Out"   input = "eq_band_8_r:In" }
              { output = "eq_band_8_r:Out"   input = "eq_band_9_r:In" }
              { output = "eq_band_9_r:Out"   input = "eq_band_10_r:In" }
              { output = "eq_band_10_r:Out"  input = "limiter:Input 2" }
            ]
            inputs  = [ "inL:In" "inR:In" ]
            outputs = [ "limiter:Output 1" "limiter:Output 2" ]
          }
          audio.channels = 2
          audio.position = [ FL FR ]
          capture.props = {
            node.name        = "effect_input.eq10"
            media.class      = "Audio/Sink"
            priority.session = 2500
          }
          playback.props = {
            node.name    = "effect_output.eq10"
            node.passive = true
          }
        }
      }
    ]
  '';

  # WebRTC Echo-Cancellation, Noise Suppression & AGC module for internal stereo mic
  xdg.configFile."pipewire/pipewire.conf.d/60-echo-cancel.conf".text = ''
    context.modules = [
      {
        name = libpipewire-module-echo-cancel
        args = {
          monitor.mode = true
          capture.props = {
            node.name = "echo_cancel_capture"
            node.passive = true
            target.object = "alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic2__source"
          }
          source.props = {
            node.name = "echo_cancel_source"
            node.description = "Clean Microphone (WebRTC Echo-Cancelled & Denoised)"
            media.class = "Audio/Source"
            priority.driver = 2100
            priority.session = 2100
          }
        }
      }
    ]
  '';
  services.playerctld.enable = true;
}
