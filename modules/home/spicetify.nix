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
    ];

    theme = {
      name = "Liquify";

      src = pkgs.fetchFromGitHub {
        owner = "NMWplays";
        repo = "Liquify";
        rev = "main";
        hash = "sha256-+/pJ2/6FhgDyMhuruBdT6aR4qoXhy6Tddfox6BGytcs=";
      };

      injectCss = true;
      injectThemeJs = true;
      replaceColors = true;
      homeConfig = true;
      overwriteAssets = false;

      # NOTE: spicetify-nix intentionally uses this misspelled name
      additonalCss =
        builtins.readFile ../../dotfiles/spicetify/snippets/hide-sidebar-scrollbar.css
        + "\n"
        + builtins.readFile ../../dotfiles/spicetify/snippets/queue-top-side-panel.css
        + "\n"
        + builtins.readFile ../../dotfiles/spicetify/snippets/more-visible-unplayable-tracks.css;
    };
  };
}