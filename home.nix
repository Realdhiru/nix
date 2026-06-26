# ~/nix/home.nix
{ config, pkgs, ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/quickshell.nix
    ./modules/home/spicetify.nix
    ./modules/home/theme.nix
  ];

  # Global Cursor Configuration
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  # Explicitly configure the internal activation option at the user level
  home.activation = {
    enableBackup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      # This forces Home Manager to handle colliding targets gracefully without crashing systemd
      export HOME_MANAGER_BACKUP_EXT="backup"
    '';
  };

  # Hardware Acceleration Flags for Brave
  home.file.".config/brave-flags.conf".text = ''
    --ozone-platform-hint=auto
    --enable-features=AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder
  '';

  xdg.configFile."hypr" = {
    source = ./dotfiles/hypr;
    force = true;
  };

  xdg.configFile."rofi" = {
    source = ./dotfiles/rofi;
    force = true;
  };

  xdg.configFile."wezterm".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/wezterm";

  xdg.configFile."fastfetch/config.jsonc".source = ./dotfiles/fastfetch/config.jsonc;

  xdg.configFile."matugen".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/matugen";

  services.easyeffects.enable = true;
  services.playerctld.enable = true;

  home.username = "realdhiru";
  home.homeDirectory = "/home/realdhiru";

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}