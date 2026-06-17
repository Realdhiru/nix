# ~/nix/home.nix
{ config, ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/quickshell.nix
    ./modules/home/spicetify.nix
  ];

  # Force fallback naming to prevent deployment system blocks during early systemd activation
  home.backupFileExtension = "backup";

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