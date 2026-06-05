{ config, pkgs, ... }:

{
  home.username = "realdhiru";
  home.homeDirectory = "/home/realdhiru";

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;

  programs.zsh.enable = true;

  programs.starship.enable = true;
}
