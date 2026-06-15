{ config, ... }:

{
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nix/dotfiles/hypr/scripts/quickshell";
}