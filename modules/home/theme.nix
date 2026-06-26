{ pkgs, ... }:

{
  gtk = {
    enable = true;
    iconTheme = {
      name = "buuf-nestort";
      package = pkgs.buuf-nestort-icon-theme;
    };
  };
}
