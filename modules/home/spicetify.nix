{ pkgs, inputs, ... }:

let
  spicePkgs =
    inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  programs.spicetify = {
    enable = true;
    enabledCustomApps = with spicePkgs.apps; [
      marketplace
    ];

#    theme = spicePkgs.themes.catppuccin;
#    colorScheme = "mocha";
#
#    enabledExtensions = with spicePkgs.extensions; [
#      adblockify
#      hidePodcasts
#      shuffle
#      beautifulLyrics
#      fullAppDisplay
#    ];
  };
}