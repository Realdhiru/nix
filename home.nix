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

  # PCManFM-Qt: file-based config (app reads/writes this INI directly, no
  # other mechanism), so the few mixed settings live inline here. SuCommand
  # needs a helper because pkexec strips env vars — expand BEFORE it launches.
  xdg.configFile."pcmanfm-qt/default/settings.conf" = {
    force = true;
    text = ''
      [System]
      SuCommand=${config.home.homeDirectory}/.local/bin/pcman-root %s
      Terminal=wezterm
      Archiver=lxqt-archiver
    '';
  };

  home.file.".local/bin/pcman-root" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # pcmanfm - open as root with the display env intact under pkexec
      exec pkexec env \
        WAYLAND_DISPLAY="''${XDG_RUNTIME_DIR}/''${WAYLAND_DISPLAY}" \
        XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR}" \
        dbus-run-session -- "$@"
    '';
  };

  services.easyeffects.enable = true;
  services.playerctld.enable = true;

  home.username = "realdhiru";
  home.homeDirectory = "/home/realdhiru";

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}