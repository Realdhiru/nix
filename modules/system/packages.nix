{ pkgs, inputs, ... }:

let
  # Quickshell's stock wrapper only exposes qtbase/qtdeclarative/qtwayland/
  # qtsvg QML modules. Lock.qml needs QtMultimedia (MediaPlayer/VideoOutput)
  # for live video wallpapers, so wrap the binary to add its QML dir and
  # multimedia plugin path (libffmpegmediaplugin.so) to the search paths.
  qtmultimedia = pkgs.qt6Packages.qtmultimedia;
  quickshellWrapped = pkgs.symlinkJoin {
    name = "quickshell-wrapped";
    paths = [ pkgs.quickshell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/quickshell \
        --prefix NIXPKGS_QT6_QML_IMPORT_PATH ':' "${qtmultimedia}/lib/qt-6/qml" \
        --prefix QT_PLUGIN_PATH ':' "${qtmultimedia}/lib/qt-6/plugins"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    # CLI & Core Utilities
    vim git curl wget tree jq yq-go bc socat python3 btop weathr util-linux

    # Development & Terminal
    tmux
    vscodium
    wezterm
    fastfetch

    # Browsers
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    brave

    # File Management
    ntfs3g pcmanfm-qt lxqt.lxqt-archiver ffmpegthumbnailer gdk-pixbuf librsvg webp-pixbuf-loader libheif libheif.out libjxl libjxl.out

    # Launchers & Clipboard
    rofi wl-clipboard cliphist

    # Screenshots & Recording
    grim slurp grimblast gpu-screen-recorder gpu-screen-recorder-gtk

    # Media & Display
    mpv mpvpaper awww playerctl brightnessctl easyeffects cava loupe ffmpeg imagemagick zbar

    # Documents & Creative
    kdePackages.okular onlyoffice-desktopeditors blender kdePackages.kdenlive parabolic

    # Audio & Networking
    pwvucontrol networkmanagerapplet blueman bluetuith

    # Power & Sensors
    acpi iw lm_sensors

    # Desktop Integration
    libnotify polkit_gnome hypridle hyprlock quickshellWrapped qt6Packages.qtmultimedia matugen

    powertop psmisc hyprsunset nodejs banner usbutils opencode repomix

    # System / Desktop Integration
    file gsettings-desktop-schemas

    clamav
    aide
    lynis 

    vulnix
    antigravity-ide


  ];

}