{ pkgs, ... }:

{
  home.packages = with pkgs; [
    wezterm
  ];

  xdg.configFile."wezterm/wezterm.lua".source =
    ../../dotfiles/wezterm/wezterm.lua;
}