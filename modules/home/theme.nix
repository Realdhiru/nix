{ config, lib, pkgs, ... }:
{
  gtk = {
    enable = true;
    theme = { name = "adwaita-dark"; package = pkgs.gnome-themes-extra; };
    iconTheme = { name = "buuf-nestort"; package = pkgs.buuf-nestort-icon-theme; };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  xdg.configFile."gtk-3.0/gtk.css".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/matugen/gtk.css";
  xdg.configFile."gtk-4.0/gtk.css".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/matugen/gtk.css";

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "fusion";
  };
  home.packages = with pkgs; [ qt6Packages.qt6ct qt5ct ];

  # matugen writes the color VALUES here; qt5ct/qt6ct's own conf (static, below)
  # points at this file as its color scheme source.
  xdg.configFile."qt5ct/colors/matugen.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/matugen/qtct.conf";
  xdg.configFile."qt6ct/colors/matugen.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/matugen/qtct.conf";

  xdg.configFile."qt5ct/qt5ct.conf".text = ''
    [Appearance]
    color_scheme_path=${config.home.homeDirectory}/.config/qt5ct/colors/matugen.conf
    custom_palette=true
    icon_theme=buuf-nestort
    stylesheets=${config.home.homeDirectory}/.cache/matugen/qt-style.qss
    style=Fusion
  '';
  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    color_scheme_path=${config.home.homeDirectory}/.config/qt6ct/colors/matugen.conf
    custom_palette=true
    icon_theme=buuf-nestort
    stylesheets=${config.home.homeDirectory}/.cache/matugen/qt-style.qss
    style=Fusion
  '';
}