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

    enabledExtensions = [
      {
        src = ./spicetify;
        name = "lyrics-raf-fallback.js";
      }
    ];

    theme = {
      name = "Liquify";

      src = pkgs.fetchFromGitHub {
        owner = "NMWplays";
        repo = "Liquify";
        rev = "69dbb54495fb2217838d3bfbb6fdbae4e4d30b00";
        hash = "sha256-+/uJFp834gK2EiJO9rWOJMcRIXtLroUzV9C1dMhggvM=";
      };
    };
  };
}