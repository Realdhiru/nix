{ config, lib, ... }:

{
  xdg.configFile."rofi/config.rasi".source = config.lib.file.mkOutOfStoreSymlink "/home/realdhiru/nix/dotfiles/rofi/config.rasi";
  xdg.configFile."rofi/theme.rasi".source = config.lib.file.mkOutOfStoreSymlink "/home/realdhiru/nix/dotfiles/rofi/theme.rasi";
}