{ config, ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/quickshell.nix
    ./modules/home/spicetify.nix
  ];

  xdg.configFile."hypr" = {
    source = ./dotfiles/hypr;
    force = true;
  };

  xdg.configFile."matugen".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/matugen";

  xdg.configFile."rofi" = {
    source = ./dotfiles/rofi;
    force = true;
  };

  home.username = "realdhiru";
  home.homeDirectory = "/home/realdhiru";

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}