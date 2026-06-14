{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [

    # CLI
    vim
    git
    curl
    wget
    tree
    jq
    yq-go
    bc
    socat
    python3
    fastfetch
    btop
    weathr

    # Development
    vscodium

    # Browsers
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    brave

    # Terminal
    wezterm

    # File management
    thunar
    xfce4-exo
    fsearch
    ntfs3g

    # Launchers and clipboard
    rofi
    wl-clipboard
    cliphist

    # Screenshots and recording
    grim
    slurp
    grimblast
    wf-recorder
    gpu-screen-recorder
    gpu-screen-recorder-gtk

    # Media
    mpv
    mpvpaper
    playerctl
    brightnessctl
    easyeffects
    cava

    # Images and thumbnails
    loupe
    ffmpeg
    imagemagick
    zbar

    # Documents
    kdePackages.okular
    onlyoffice-desktopeditors

    # Creative
    blender
    kdePackages.kdenlive

    # Downloads
    parabolic

    # Audio
    pwvucontrol

    # Networking and Bluetooth
    networkmanager
    networkmanagerapplet
    bluez
    blueman
    bluetuith

    # Power and sensors
    acpi
    iw
    lm_sensors
    libva-utils

    # Intel video acceleration
    intel-media-driver
    vpl-gpu-rt

    # Notifications and authentication
    libnotify
    polkit_gnome

    # Hyprland
    hypridle
    hyprlock

    # Quickshell
    quickshell
    qt6Packages.qtmultimedia
    matugen
  ];
}