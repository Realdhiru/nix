{ config, lib, ... }:

{ 
  xdg.configFile."rofi/config.rasi".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/programs/rofi/config.rasi";
}
