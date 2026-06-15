{ ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/spicetify.nix
    ./dotfiles/rofi/default.nix
  ];

  xdg.configFile."hypr" = {
    source = ./dotfiles/hypr;
    force = true;
  };

  xdg.configFile."quickshell" = {
    source = ./dotfiles/quickshell;
    force = true;
  };

  xdg.configFile."matugen" = {
    source = ./dotfiles/matugen;
    force = true;
  };

  xdg.configFile."rofi" = {
  source = ./dotfiles/rofi;
  force = true;
};

  home.username = "realdhiru";
  home.homeDirectory = "/home/realdhiru";

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}