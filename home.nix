{ config, pkgs, ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/spicetify.nix
    ./modules/home/theme.nix
      ./modules/home/desktop-entries.nix

  ];

  # Explicitly configure the internal activation option at the user level
  home.activation = {
    enableBackup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      # This forces Home Manager to handle colliding targets gracefully without crashing systemd
      export HOME_MANAGER_BACKUP_EXT="backup"
    '';

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
    --ozone-platform-hint=auto
    --use-gl=angle
    --enable-features=VaapiVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder
  '';

  xdg.configFile."hypr" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/hypr";
    force = true;
  };

  xdg.configFile."rofi" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/rofi";
    force = true;
  };

  xdg.configFile."wezterm".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/wezterm";

 xdg.configFile."fastfetch/config.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/fastfetch/config.jsonc";
      
  xdg.configFile."matugen".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/matugen";

  # VSCodium: home-manager's xdg.configFile can only ever symlink into the
  # read-only generation store, which VSCodium cannot write through. So on
  # every rebuild we copy the repo file onto the real config path after the
  # writeBoundary step (this overwrites the managed symlink). Changes flow
  # back to the repo via the vscodium-settings-sync watcher service.
  home.activation.vscodiumSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/VSCodium/User"
    cp -f ${./dotfiles/vscodium/settings.json} "$HOME/.config/VSCodium/User/settings.json"
    chmod 644 "$HOME/.config/VSCodium/User/settings.json"
  '';

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

  services.easyeffects.enable = true;
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

  # VSCodium settings mirror: live config → nix repo (git). The unit is the
  # sole trigger; no rebuild is ever run by it.
  systemd.user.services.vscodium-settings-sync = {
    Unit = {
      Description = "Mirror VSCodium settings.json into the nix repo";
    };
    Service = {
      ExecStart = "${pkgs.bash}/bin/bash %h/nix/dotfiles/vscodium/sync_settings.sh";
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "PATH=/etc/profiles/per-user/realdhiru/bin:/run/current-system/sw/bin"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  home.username = "realdhiru";
  home.homeDirectory = "/home/realdhiru";

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}