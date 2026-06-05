{ ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/browser.nix
    ./modules/home/zed.nix
    ./modules/home/wezterm.nix
    ./modules/home/hyprland.nix
  ];

  home.username = "realdhiru";
  home.homeDirectory = "/home/realdhiru";

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}
