{ config, pkgs, inputs, user, lib, ... }:

{
  imports = [
    ./audio.nix
    ./desktop-state.nix
    ./monitors.nix
    ./shell.nix
    ./spicetify.nix
    ./theme.nix
  ];

  # Declarative Default Wallpaper (Flake store-path)
  home.sessionVariables.DEFAULT_WALLPAPER = "${../../dotfiles/wallpaper/default.jpg}";
  home.sessionVariables.WALLPAPER_DIR = "${config.home.homeDirectory}/${user.desktop.wallpaperDirectory}";
  home.sessionVariables.WALLPAPER_ORGANIZER_PROJECTS_DIR = "${config.home.homeDirectory}/${user.desktop.wallpaperOrganizerProjectsDirectory}";
  home.sessionVariables.HYPR_REFRESH_AC = toString user.desktop.refreshRate.ac;
  home.sessionVariables.HYPR_REFRESH_BATTERY = toString user.desktop.refreshRate.battery;
  home.sessionVariables.NIX_CONFIG_DIR = "${config.home.homeDirectory}/${user.desktop.repositoryDirectory}";
  home.sessionVariables.DESKTOP_STATE_DIR = config.desktop.stateDir;
  home.sessionVariables.TERMINAL = user.desktop.terminal;
  home.sessionVariables.BROWSER = user.desktop.browser;
  home.sessionVariables.EDITOR = user.desktop.editor;
  home.sessionVariables.FILEMANAGER = user.desktop.fileManager;
  home.sessionVariables.HYPR_KEYBOARD_LAYOUT = user.keyboard.layout;
  home.sessionVariables.HYPR_KEYBOARD_OPTIONS = user.keyboard.options;
  xdg.configFile."environment.d/wallpaper.conf".text =
    "DEFAULT_WALLPAPER=${../../dotfiles/wallpaper/default.jpg}\nWALLPAPER_DIR=${config.home.homeDirectory}/${user.desktop.wallpaperDirectory}\nWALLPAPER_ORGANIZER_PROJECTS_DIR=${config.home.homeDirectory}/${user.desktop.wallpaperOrganizerProjectsDirectory}\n";
  xdg.configFile."environment.d/desktop_state.conf".text =
    "DESKTOP_STATE_DIR=${config.desktop.stateDir}\n";

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

      exec ${pkgs.brave}/bin/brave \
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
      exec ${pkgs.onlyoffice-desktopeditors}/bin/onlyoffice-desktopeditors --system-title-bar "$@"
    '';
  };

  xdg.configFile."hypr" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/${user.desktop.repositoryDirectory}/dotfiles/hypr";
    force = true;
  };

  xdg.configFile."fuzzel" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/${user.desktop.repositoryDirectory}/dotfiles/fuzzel";
    force = true;
  };


  xdg.configFile."fastfetch/config.jsonc" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/${user.desktop.repositoryDirectory}/dotfiles/fastfetch.jsonc";
    force = true;
  };

  xdg.configFile."wallust" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/${user.desktop.repositoryDirectory}/dotfiles/wallust";
    force = true;
  };

  xdg.configFile."wallpaper" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/${user.desktop.repositoryDirectory}/dotfiles/wallpaper";
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


  # PCManFM-Qt: file-based config (app reads/writes this INI directly, no
  # other mechanism), so the few mixed settings live inline here.
  xdg.configFile."pcmanfm-qt/default/settings.conf" = {
    force = true;
    text = ''
      [Places]
      HiddenPlaces=${config.home.homeDirectory}/Desktop, menu:///applications/

      [System]
      Terminal=alacritty
      Archiver=lxqt-archiver

      [Thumbnail]
      MaxThumbnailFileSize=262144
    '';
  };


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



  programs.alacritty.enable = true;

  xdg.configFile."alacritty/alacritty.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/${user.desktop.repositoryDirectory}/dotfiles/alacritty/alacritty.toml";
    force = true;
  };

  home.username = user.username;
  home.homeDirectory = user.homeDirectory;
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}
