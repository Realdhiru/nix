{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
    nerd-fonts.symbols-only

    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    font-awesome
    liberation_ttf
  ];

  fonts.fontconfig = {
    enable = true;
    hinting.style = "slight";
    subpixel.rgba = "none";
    defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" "Noto Sans CJK JP" "Symbols Nerd Font" ];
      sansSerif = [ "Noto Sans" "Noto Sans CJK JP" ];
      serif = [ "Noto Serif" "Noto Serif CJK JP" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}