{ config, lib, pkgs, user, ... }:
let
  gtkTheme = if user.desktop.themeMode == "dark" then "Adwaita:dark" else "Adwaita";
  colorScheme = if user.desktop.themeMode == "dark" then "prefer-dark" else "prefer-light";
  kdeColorScheme = if user.desktop.themeMode == "dark" then "BreezeDark" else "Breeze";
in
{
  home.sessionVariables.GTK_THEME = gtkTheme;
  home.sessionVariables.QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";

  # GTK3 config channels (settings.ini/dconf) don't apply here; environment is
  # the only reliable channel (proven). sessionVariables covers GUI/logins;
  # user-environment.d covers systemd user services (e.g. the portal).
  xdg.configFile."environment.d/gtk-theme.conf".text =
    "GTK_THEME=${gtkTheme}\n";
  xdg.configFile."environment.d/qt-theme.conf".text =
    "QT_QPA_PLATFORMTHEME=qt6ct\n";

  gtk = {
    enable = true;
    theme = { name = gtkTheme; package = pkgs.gnome-themes-extra; };
    iconTheme = { name = "buuf-nestort"; package = pkgs.buuf-nestort-icon-theme; };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = user.desktop.themeMode == "dark";
    gtk3.extraConfig.gtk-decoration-layout = ":";
    gtk4.extraConfig.gtk-application-prefer-dark-theme = user.desktop.themeMode == "dark";
    gtk4.extraConfig.gtk-decoration-layout = ":";
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = colorScheme;
    gtk-theme = gtkTheme;
  };

  dconf.settings."org/gnome/desktop/wm/preferences" = {
    button-layout = ":";
  };

  xdg.dataFile."icons/buuf-nestort" = {
    source = "${pkgs.buuf-nestort-icon-theme}/share/icons/buuf-nestort";
    force = true;
  };

  xdg.configFile."gtk-3.0/gtk.css".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/theme/gtk.css";
  xdg.configFile."gtk-4.0/gtk.css".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/theme/gtk.css";

  qt = {
    enable = true;
    platformTheme.name = "qtct";
  };
  home.packages = with pkgs; [ qt6Packages.qt6ct libsForQt5.qt5ct kdePackages.breeze glib inotify-tools ];

  xdg.dataFile."color-schemes/BreezeDark.colors".source =
    "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors";

  # Global cursor theme
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 32;
  };
  
  # Wallust writes the color values to ~/.cache/theme/qtct.conf and qt-style.qss
  xdg.configFile."qt5ct/colors/theme.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/theme/qtct.conf";
  xdg.configFile."qt6ct/colors/theme.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/theme/qtct.conf";

  xdg.configFile."qt5ct/qss/qt-style.qss".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/theme/qt-style.qss";
  xdg.configFile."qt6ct/qss/qt-style.qss".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/theme/qt-style.qss";

  xdg.configFile."qt5ct/qt5ct.conf" = {
    force = true;
    text = ''
      [Appearance]
      color_scheme_path=${config.home.homeDirectory}/.config/qt5ct/colors/theme.conf
      custom_palette=true
      icon_theme=buuf-nestort
      style=Fusion

      [Interface]
      stylesheets=${config.home.homeDirectory}/.config/qt5ct/qss/qt-style.qss
    '';
  };
  xdg.configFile."qt6ct/qt6ct.conf" = {
    force = true;
    text = ''
      [Appearance]
      color_scheme_path=${config.home.homeDirectory}/.config/qt6ct/colors/theme.conf
      custom_palette=true
      icon_theme=buuf-nestort
      style=Fusion

      [Interface]
      stylesheets=${config.home.homeDirectory}/.config/qt6ct/qss/qt-style.qss
    '';
  };

  # Enforce dark theme for KDE Frameworks applications (Okular, Dolphin, Gwenview)
  xdg.configFile."kdeglobals".text = ''
    [General]
    ColorScheme=${kdeColorScheme}

    [KDE]
    colorScheme=${kdeColorScheme}
  '';
}
