{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    quickshell
  ];

  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/quickshell";
}