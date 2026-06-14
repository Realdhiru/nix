{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    quickshell
  ];

  # 1. Copy the entire quickshell QML/JS configuration directory into the Nix store
  xdg.configFile."quickshell".source = ../../dotfiles/quickshell;

  # 2. Declaratively define the background scripts with explicit executable permissions
  xdg.configFile."hypr/scripts/wallpaper_thumbnail.sh" = {
    source = ../../dotfiles/hypr/scripts/wallpaper_thumbnail.sh;
    executable = true;
  };

  xdg.configFile."hypr/scripts/set_wallpaper.sh" = {
    source = ../../dotfiles/hypr/scripts/set_wallpaper.sh;
    executable = true;
  };

  xdg.configFile."hypr/scripts/qs_manager.sh" = {
    source = ../../dotfiles/hypr/scripts/qs_manager.sh;
    executable = true;
  };
}