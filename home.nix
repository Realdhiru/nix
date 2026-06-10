
{ ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/browser.nix
    ./modules/home/wezterm.nix
    ./modules/home/hyprland.nix
    ./modules/home/quickshell.nix
    ./modules/home/fastfetch.nix
  ];

  programs.spicetify =
let
  spicePkgs =
    inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  enable = true;

  enabledExtensions = with spicePkgs.extensions; [
    adblock
    hidePodcasts
    shuffle
  ];

  enabledCustomApps = with spicePkgs.apps; [
    newReleases
  ];

  theme = spicePkgs.themes.catppuccin;

  colorScheme = "mocha";
};

  home.username = "realdhiru";
  home.homeDirectory = "/home/realdhiru";

  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}
