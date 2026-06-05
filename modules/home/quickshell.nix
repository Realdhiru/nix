{ pkgs, ... }:

{
  home.packages = with pkgs; [
    quickshell
  ];

  xdg.configFile."quickshell".source = ../../dotfiles/quickshell;
}
