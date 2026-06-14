{ ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/quickshell.nix
    ./modules/home/spicetify.nix
    ./dotfiles/rofi/default.nix
  ];

  xdg.configFile."hypr" = {
    source = ./dotfiles/hypr;
    force = true;
  };

  home.username = "realdhiru";
  home.homeDirectory = "/home/realdhiru";

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}