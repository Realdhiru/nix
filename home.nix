{ config, pkgs, inputs, user, lib, ... }:

{
  imports = [
    ./modules/home/audio.nix
    ./modules/home/desktop-state.nix
    ./modules/home/shell.nix
    ./modules/home/spicetify.nix
    ./modules/home/theme.nix
  ];

  # Declarative Default Wallpaper (Flake store-path)
  home.sessionVariables.DEFAULT_WALLPAPER = "${./dotfiles/wallpaper/default.jpg}";
  home.sessionVariables.DESKTOP_STATE_DIR = config.desktop.stateDir;
  home.sessionVariables.TERMINAL = "alacritty";
  home.sessionVariables.BROWSER = "brave";
  home.sessionVariables.EDITOR = "gram";
  home.sessionVariables.FILEMANAGER = "pcmanfm-qt";
  xdg.configFile."environment.d/wallpaper.conf".text =
    "DEFAULT_WALLPAPER=${./dotfiles/wallpaper/default.jpg}\n";
  xdg.configFile."environment.d/desktop_state.conf".text =
    "DESKTOP_STATE_DIR=${config.desktop.stateDir}\n";

  # Host-specific declarative monitor override (Samsung 2.8K OLED panel)
  # Dynamic refresh-rate-by-power-source: derives target resolution and available
  # refresh rates directly from the panel's hardware EDID detailed timings (no hardcoded rates).
  # 60Hz on battery / 120Hz on AC enforced declaratively across startup, hotplug, and compositor reloads.
  xdg.configFile."hypr-local/monitors.lua" = {
    force = true;
    text = ''
      local function is_ac_online()
          for _, path in ipairs({
              "/sys/class/power_supply/AC0/online",
              "/sys/class/power_supply/ADP1/online",
              "/sys/class/power_supply/AC/online",
              "/sys/class/power_supply/ucsi-source-psy-USBC000:001/online"
          }) do
              local f = io.open(path, "r")
              if f then
                  local v = f:read("*l")
                  f:close()
                  if v and v:match("1") then return true end
              end
          end
          return false
      end

      local function get_edid_modes(edid_bytes)
          local modes = {}
          if not edid_bytes or #edid_bytes < 128 then return modes end
          for _, offset in ipairs({54, 72, 90, 108}) do
              local b1 = string.byte(edid_bytes, offset + 1)
              local b2 = string.byte(edid_bytes, offset + 2)
              if b1 and b2 and (b1 ~= 0 or b2 ~= 0) then
                  local pix_clk = (b1 + b2 * 256) * 10000
                  local b3 = string.byte(edid_bytes, offset + 3)
                  local b4 = string.byte(edid_bytes, offset + 4)
                  local b5 = string.byte(edid_bytes, offset + 5)
                  local b6 = string.byte(edid_bytes, offset + 6)
                  local b7 = string.byte(edid_bytes, offset + 7)
                  local b8 = string.byte(edid_bytes, offset + 8)

                  local h_act = b3 + (math.floor(b5 / 16) * 256)
                  local h_blank = b4 + ((b5 % 16) * 256)
                  local v_act = b6 + (math.floor(b8 / 16) * 256)
                  local v_blank = b7 + ((b8 % 16) * 256)

                  local h_total = h_act + h_blank
                  local v_total = v_act + v_blank
                  if h_total > 0 and v_total > 0 then
                      local rr = pix_clk / (h_total * v_total)
                      table.insert(modes, { width = h_act, height = v_act, rr = rr })
                  end
              end
          end
          return modes
      end

      local function resolve_mode()
          local edid_paths = {
              "/sys/class/drm/card1-eDP-1/edid",
              "/sys/class/drm/card0-eDP-1/edid",
          }
          local modes = {}
          for _, path in ipairs(edid_paths) do
              local f = io.open(path, "rb")
              if f then
                  local content = f:read("*a")
                  f:close()
                  modes = get_edid_modes(content)
                  if #modes > 0 then break end
              end
          end

          if #modes == 0 then
              return "preferred"
          end

          local max_mode = modes[1]
          local min_mode = modes[1]
          for _, m in ipairs(modes) do
              if m.rr > max_mode.rr then max_mode = m end
              if m.rr < min_mode.rr then min_mode = m end
          end

          local chosen = is_ac_online() and max_mode or min_mode
          return string.format("%dx%d@%d", chosen.width, chosen.height, math.floor(chosen.rr + 0.5))
      end

      local target_mode = resolve_mode()
      local function get_transform()
          local state_dir = os.getenv("DESKTOP_STATE_DIR") or ((os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/desktop")
          local f = io.open(state_dir .. "/monitors/transform.txt", "r")
          if f then
              local t = f:read("*l")
              f:close()
              return tonumber(t) or 0
          end
          return 0
      end
      local t = get_transform()
      hl.monitor({ output = "desc:Samsung Display Corp. 0x4180", mode = target_mode, position = "0x0", scale = 2, bitdepth = 10, transform = t })
      hl.monitor({ output = "eDP-1", mode = target_mode, position = "0x0", scale = 2, bitdepth = 10, transform = t })
    '';
  };

  # Universal Hardware Acceleration Wrapper for Brave & Web Apps:
  # Injects VA-API zero-copy and ANGLE GL flags into the PATH wrapper, ensuring
  # hardware decoding on Intel/AMD/Nvidia without relying on unparsed flags.conf.
  # Dynamically suppresses detached DownloadBubble popup subsurfaces via partial_view_enabled
  # profile preferences to prevent out-of-screen Wayland anchor offset bugs in app and multi-window modes.
  home.file.".local/bin/brave" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      for pref in "$HOME/.config/BraveSoftware/Brave-Browser/"*"/Preferences"; do
        if [ -f "$pref" ] && command -v jq >/dev/null 2>&1; then
          if jq -e '.download_bubble.partial_view_enabled != false' "$pref" >/dev/null 2>&1; then
            tmp="$pref.tmp.$$"
            jq '.download_bubble.partial_view_enabled = false' "$pref" > "$tmp" && mv -f "$tmp" "$pref"
          fi
        fi
      done

      exec /run/current-system/sw/bin/brave \
        --use-gl=angle \
        --use-angle=gl \
        --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations \
        --enable-zero-copy \
        "$@"
    '';
  };

  # Declarative OnlyOffice Wrapper:
  # Enforces system window decorations to prevent CEF custom titlebar redraw/blanking drops under XWayland.
  home.file.".local/bin/onlyoffice-desktopeditors" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec /run/current-system/sw/bin/onlyoffice-desktopeditors --system-title-bar "$@"
    '';
  };

  xdg.configFile."hypr" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/hypr";
    force = true;
  };

  xdg.configFile."fuzzel" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/fuzzel";
    force = true;
  };


  xdg.configFile."fastfetch/config.jsonc" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/fastfetch.jsonc";
    force = true;
  };
      
  xdg.configFile."wallust" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/wallust";
    force = true;
  };

  xdg.configFile."wallpaper" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/wallpaper";
    force = true;
  };

  # Declarative mpv MPRIS plugin symlink (auto-tracked across nix store generations)
  xdg.configFile."mpv/scripts/mpris.so" = {
    source = "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";
    force = true;
  };

  # Hide misleading / unused entries from application launcher (Fuzzel)
  xdg.desktopEntries."pcmanfm-qt-desktop-pref" = {
    name = "Desktop";
    noDisplay = true;
  };

  xdg.desktopEntries."org.opengamingcollective.rog-control-center" = {
    name = "ROG Control Center";
    noDisplay = true;
  };

  # Mutable user-managed MIME associations (allows casual right-click "Set as Default" in PCManFM-Qt)
  xdg.mimeApps.enable = false;

  # WirePlumber: Disable conflicting libcamera monitor so UVC cameras are exclusively handled by V4L2
  xdg.configFile."wireplumber/wireplumber.conf.d/50-disable-libcamera.conf" = {
    force = true;
    text = ''
      wireplumber.profiles = {
        main = {
          monitor.libcamera = disabled
        }
      }
    '';
  };

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
      ]

      wireplumber.settings = {
        "linking.allow-moving-streams" = true
        "linking.follow-default-target" = true
        "bluetooth.autoswitch-to-headset-profile" = false
        "bluetooth.profile-preference" = "quality"
        "bluetooth.use-persistent-storage" = false
        "device.routes.mute-on-bluetooth-playback-removed" = true
        "device.routes.mute-on-alsa-playback-removed" = true
      }
    '';
  };

  # PCManFM-Qt: file-based config (app reads/writes this INI directly, no
  # other mechanism), so the few mixed settings live inline here.
  xdg.configFile."pcmanfm-qt/default/settings.conf" = {
    force = true;
    text = ''
      [Places]
      HiddenPlaces=/home/${user.username}/Desktop, menu:///applications/

      [System]
      Terminal=alacritty
      Archiver=lxqt-archiver

      [Thumbnail]
      MaxThumbnailFileSize=262144
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
                  "Depth"                = 0.85
                  "Low Cutoff (Hz)"      = 150.0
                  "Air Depth"            = 0.20
                  "Transient Protection" = 0.50
                  "Release (ms)"         = 80.0
                  "Reverb Duck (dB)"     = 2.5
                }
              }

              # Fast Lookahead Limiter (Steve Harris SWH LADSPA 1913) - Master Output Speaker Protection
              { type = ladspa
                name = limiter
                plugin = "${pkgs.ladspaPlugins}/lib/ladspa/fast_lookahead_limiter_1913.so"
                label = fastLookaheadLimiter
                control = {
                  "Input gain (dB)"  = 0.0
                  "Limit (dB)"       = -1.0
                  "Release time (s)" = 0.50
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

  # Focus time tracking daemon — single authoritative lifecycle owner.
  # Previously launched via Hyprland `exec-once` + a shell supervisor loop
  # (launch_daemon.sh); both removed. systemd restarts it on crash, boots,
  # Hyprland restarts, nixos-rebuild, etc. without any other supervision.
  systemd.user.services.focustime-daemon = {
    Unit = {
      Description = "Focus time tracking daemon (Hyprland active window)";
    };
    Service = {
      ExecStart = "%h/.config/hypr/scripts/quickshell/focustime/focus_daemon";
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "QS_STATE_FOCUSTIME=%h/.local/state/desktop/focustime"
        "QS_RUN_FOCUSTIME=%t/quickshell/focustime"
        "PATH=/run/current-system/sw/bin"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Clipboard history recorders — supervised systemd replacements for the
  # unsupervised `wl-paste --watch cliphist store` one-shots previously
  # launched from Hyprland startup.lua. If a watcher dies (or Hyprland
  # restarts and the Wayland socket drops), systemd restarts it in 2s so
  # cliphist can never silently stop recording. Same process count as
  # before, no resident shell, zero extra battery cost.
  systemd.user.services.cliphist-text-watcher = {
    Unit = {
      Description = "Record text clipboard selections into cliphist history";
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "always";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.cliphist-image-watcher = {
    Unit = {
      Description = "Record image clipboard selections into cliphist history";
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "always";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Declarative wallpaper daemon managed by systemd
  systemd.user.services.awww-daemon = {
    Unit = {
      Description = "awww wallpaper daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.awww}/bin/awww-daemon --no-cache --format argb";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Per-output mpvpaper video wallpaper template service
  systemd.user.services."mpvpaper@" = {
    Unit = {
      Description = "mpvpaper video wallpaper for %i";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      EnvironmentFile = "%h/.local/state/mpvpaper/%i.env";
      ExecStart = "${pkgs.mpvpaper}/bin/mpvpaper -p -o \"no-audio --load-scripts=no --loop-file=inf --loop-playlist=inf --hwdec=auto-safe --panscan=1.0 --input-ipc-server=%t/mpvpaper-%i.sock\" %i \${WALLPAPER_VIDEO}";
      Restart = "on-failure";
    };
  };

  # Declarative color temperature and display CTM daemon managed by systemd
  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "hyprsunset color temperature and gamma manager";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset -i";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Native event-driven refresh rate updater on AC plug/unplug events
  systemd.user.services.hypr-refresh-rate = {
    Unit = {
      Description = "Apply declarative monitor refresh rate on power event";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "apply-refresh-rate" ''
        set -euo pipefail
        if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
          SIG=$(find "$runtime_dir/hypr" -maxdepth 2 -name ".socket.sock" -printf '%T@ %h\n' 2>/dev/null | sort -nr | head -n 1 | awk '{print $2}' | xargs -r basename || true)
          if [ -n "$SIG" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE="$SIG"
          fi
        fi
        if [ -z "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          echo "hypr-refresh-rate: failed to find active HYPRLAND_INSTANCE_SIGNATURE in ''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" >&2
          exit 1
        fi
        echo "hypr-refresh-rate: applying monitors.lua with signature $HYPRLAND_INSTANCE_SIGNATURE"
        ${pkgs.hyprland}/bin/hyprctl eval "dofile(os.getenv('HOME') .. '/.config/hypr-local/monitors.lua')"
      ''}";
    };
  };


  programs.alacritty.enable = true;

  xdg.configFile."alacritty/alacritty.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/alacritty/alacritty.toml";
    force = true;
  };

  home.username = user.username;
  home.homeDirectory = "/home/${user.username}";
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}