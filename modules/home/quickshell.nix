{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    quickshell
    qt6.qtmultimedia
  ];

  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/quickshell";
}