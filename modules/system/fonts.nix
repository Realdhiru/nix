{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
    nerd-fonts.symbols-only

    noto-fonts
    liberation_ttf
  ];

  fonts.fontconfig = {
    enable = true;
    hinting.style = "slight";
    subpixel.rgba = "rgb";
  };
}