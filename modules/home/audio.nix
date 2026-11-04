{ lib, ... }:

{
  options.desktop.audio.karaoke.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable system-wide Karaoke DSP filter chain";
  };
}
