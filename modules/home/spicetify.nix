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

    enabledExtensions = with spicePkgs.extensions; [
      adblockify
      spicyLyrics
      aiBandBlocker
      fullAlbumDate
      sidebarCustomizer
      spicyTracker
    ];

    theme = {
      name = "Liquify";

      src = pkgs.fetchFromGitHub {
        owner = "NMWplays";
        repo = "Liquify";
        rev = "main";
        hash = "sha256-+/pJ2/6FhgDyMhuruBdT6aR4qoXhy6Tddfox6BGytcs=";
      };
    };
  };
}