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

  # Distrobox .deb installer helper and file manager integration
  home.file.".local/bin/distrobox-install-deb" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/scripts/distrobox-install-deb.sh";
  };

  # Application association for .deb packages (shows directly in PCManFM-Qt "Open With")
  xdg.dataFile."applications/distrobox-install.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Install in Distrobox
    Comment=Install Debian package inside Distrobox deb-box container
    Exec=${config.home.homeDirectory}/.local/bin/distrobox-install-deb %f
    Icon=system-software-install
    Terminal=false
    Categories=System;Utility;
    MimeType=application/vnd.debian.binary-package;application/x-deb;
    NoDisplay=true
  '';

  # Declarative ChatGPT Distrobox desktop entry: strictly locked to x-scheme-handler/codex
  # completely stripped of HTTP/HTTPS/HTML and generic document handlers to prevent browser hijacking.
  xdg.dataFile."applications/deb-box-chatgpt.desktop".text = ''
    [Desktop Entry]
    Name=ChatGPT (on deb-box)
    Comment=ChatGPT by OpenAI
    GenericName=AI assistant (on deb-box)
    Exec=sh -c 'ELECTRON_OZONE_PLATFORM_HINT=auto "$@" ; /run/current-system/sw/bin/distrobox stop deb-box --yes >/dev/null 2>&1 &' -- /run/current-system/sw/bin/distrobox-enter -n deb-box -- chatgpt %U
    Icon=chatgpt
    Type=Application
    StartupNotify=true
    Categories=Utility;Development;
    MimeType=x-scheme-handler/codex;
    StartupWMClass=chatgpt
  '';

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

  home.username = user.username;
  home.homeDirectory = "/home/${user.username}";
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}