{ pkgs, inputs, ... }:

let
  spicePkgs =
    inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  spicyTrackerSrc = pkgs.fetchFromGitHub {
    owner = "yodaluca23";
    repo = "spicetify-extensions";
    rev = "main";
    hash = "";
  };

  spicyLyricTranslatorSrc = pkgs.fetchFromGitHub {
    owner = "7xeh";
    repo = "SpicyLyricTranslator";
    rev = "v2.0.8";
    hash = "";
  };

in
{
  programs.spicetify = {
    enable = true;

    enabledCustomApps = with spicePkgs.apps; [
      marketplace
    ];

    enabledExtensions =
      (with spicePkgs.extensions; [
        adblockify
        spicyLyrics
        aiBandBlocker
        fullAlbumDate
        sidebarCustomizer
      ])
      ++ [
        {
          name = "SpicyTracker.js";
          src = "${spicyTrackerSrc}/SpicyTracker";
        }

        {
          name = "spicy-lyric-translator.js";
          src = "${spicyLyricTranslatorSrc}/dist";
        }
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