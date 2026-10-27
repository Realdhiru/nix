{ config, pkgs, inputs, user, lib, ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/spicetify.nix
    ./modules/home/theme.nix
  ];

  options.desktop.stateDir = lib.mkOption {
    type = lib.types.str;
    default = "${config.xdg.stateHome}/desktop";
    description = "Unified persistent state directory for desktop components";
  };

  # Declarative Default Wallpaper (Flake store-path)
  home.sessionVariables.DEFAULT_WALLPAPER = "${./dotfiles/wallpaper/default.jpg}";
  home.sessionVariables.DESKTOP_STATE_DIR = config.desktop.stateDir;
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
          for _, path in ipairs({"/sys/class/power_supply/AC0/online", "/sys/class/power_supply/ADP1/online", "/sys/class/power_supply/AC/online"}) do
              local f = io.open(path, "r")
              if f then
                  local v = f:read("*l")
                  f:close()
                  if v and v:match("1") then return true end
                  if v and v:match("0") then return false end
              end
          end
          return true
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
      hl.monitor({ output = "desc:Samsung Display Corp. 0x4180", mode = target_mode, position = "auto", scale = 2, bitdepth = 10 })
    '';
  };

  # Universal Hardware Acceleration Wrapper for Brave & Web Apps:
  # Injects VA-API zero-copy and ANGLE GL flags into the PATH wrapper, ensuring
  # hardware decoding on Intel/AMD/Nvidia without relying on unparsed flags.conf.
  # Disables DownloadBubble detached popup subsurfaces to prevent out-of-screen Wayland anchor bugs.
  home.file.".local/bin/brave" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      exec /run/current-system/sw/bin/brave \
        --use-gl=angle \
        --use-angle=gl \
        --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations \
        --disable-features=DownloadBubble,DownloadBubbleV2 \
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
      ]

      wireplumber.settings = {
        "linking.allow-moving-streams" = true
        "linking.follow-default-target" = true
        "bluetooth.autoswitch-to-headset-profile" = false
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

  # Native 10-band Equalizer filter-chain for PipeWire (replaces EasyEffects with zero background daemon overhead)
  xdg.configFile."pipewire/pipewire.conf.d/99-equalizer-sink.conf".text = ''
    context.modules = [
      { name = libpipewire-module-filter-chain
        args = {
          node.description = "PipeWire Equalizer"
          media.name       = "PipeWire Equalizer"
          filter.graph = {
            nodes = [
              { type = builtin name = eq_band_1  label = bq_peaking control = { "Freq" = 31.0   "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_2  label = bq_peaking control = { "Freq" = 63.0   "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_3  label = bq_peaking control = { "Freq" = 125.0  "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_4  label = bq_peaking control = { "Freq" = 250.0  "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_5  label = bq_peaking control = { "Freq" = 500.0  "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_6  label = bq_peaking control = { "Freq" = 1000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_7  label = bq_peaking control = { "Freq" = 2000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_8  label = bq_peaking control = { "Freq" = 4000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_9  label = bq_peaking control = { "Freq" = 8000.0 "Q" = 1.414 "Gain" = 0.0 } }
              { type = builtin name = eq_band_10 label = bq_peaking control = { "Freq" = 16000.0 "Q" = 1.414 "Gain" = 0.0 } }
            ]
            links = [
              { output = "eq_band_1:Out" input = "eq_band_2:In" }
              { output = "eq_band_2:Out" input = "eq_band_3:In" }
              { output = "eq_band_3:Out" input = "eq_band_4:In" }
              { output = "eq_band_4:Out" input = "eq_band_5:In" }
              { output = "eq_band_5:Out" input = "eq_band_6:In" }
              { output = "eq_band_6:Out" input = "eq_band_7:In" }
              { output = "eq_band_7:Out" input = "eq_band_8:In" }
              { output = "eq_band_8:Out" input = "eq_band_9:In" }
              { output = "eq_band_9:Out" input = "eq_band_10:In" }
            ]
          }
          audio.channels = 2
          audio.position = [ FL FR ]
          capture.props = {
            node.name        = "effect_input.eq10"
            media.class      = "Audio/Sink"
            priority.driver  = 2200
            priority.session = 2200
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
      ExecStart = "${pkgs.python3}/bin/python3 %h/.config/hypr/scripts/quickshell/focustime/focus_daemon.py";
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "QS_STATE_FOCUSTIME=%h/.local/state/quickshell/focustime"
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
      ExecStart = "${pkgs.mpvpaper}/bin/mpvpaper -p -o \"no-audio --load-scripts=no --loop-file=inf --loop-playlist=inf --hwdec=auto-safe --panscan=1.0\" %i \${WALLPAPER_VIDEO}";
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
      RestartSec = "1s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
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