{ config, pkgs, inputs, user, ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/spicetify.nix
    ./modules/home/theme.nix
  ];

  # Ensure dynamic state files exist before Hyprland boots
  home.activation = {
    initPowerMonitor = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      # Ensure dynamic state files exist before Hyprland boots to prevent parsing errors
      mkdir -p $HOME/.cache
      touch $HOME/.cache/hypr_power_monitor.conf
      touch $HOME/.cache/current_shader.conf
    '';
  };

  # Hardware Acceleration Flags for Brave — sole source of these flags now
  # (the package-level override in packages.nix was removed so this
  # setting only exists in one place).
  home.file.".config/brave-flags.conf".text = ''
    --ozone-platform-hint=wayland
    --use-gl=angle
    --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder
  '';

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

  xdg.configFile."wezterm/wezterm.lua" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/wezterm.lua";
    force = true;
  };

  xdg.configFile."fastfetch/config.jsonc" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/fastfetch.jsonc";
    force = true;
  };
      
  xdg.configFile."matugen" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/matugen";
    force = true;
  };

  xdg.configFile."opencode/ponytail".source =
    config.lib.file.mkOutOfStoreSymlink "${inputs.ponytail}";

  xdg.configFile."opencode/opencode.jsonc" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/opencode/opencode.jsonc";
    force = true;
  };

  # Declarative mpv MPRIS plugin symlink (auto-tracked across nix store generations)
  xdg.configFile."mpv/scripts/mpris.so" = {
    source = "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";
    force = true;
  };

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
              priority.session = 2000
              priority.driver = 2000
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
              priority.session = 2000
              priority.driver = 2000
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
              priority.session = 2000
              priority.driver = 2000
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
              priority.session = 2000
              priority.driver = 2000
            }
          }
        }
      ]

      wireplumber.settings = {
        "linking.allow-moving-streams" = true
        "linking.follow-default-target" = true
      }
    '';
  };

  # PCManFM-Qt: file-based config (app reads/writes this INI directly, no
  # other mechanism), so the few mixed settings live inline here.
  xdg.configFile."pcmanfm-qt/default/settings.conf" = {
    force = true;
    text = ''
      [System]
      Terminal=wezterm start --always-new-process --cwd .
      Archiver=lxqt-archiver

      [Thumbnail]
      MaxThumbnailFileSize=262144
    '';
  };

  # Single service-managed EasyEffects instance.
  services.easyeffects = {
    enable = true;
  };
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

  home.username = user.username;
  home.homeDirectory = "/home/${user.username}";
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}