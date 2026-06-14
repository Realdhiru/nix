{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [

    # CLI
    vim
    wget
    git
    curl
    tree
    fastfetch
    btop
    weathr
    libva-utils

    # Development
    vscodium

    # Browsers
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    brave

    # File Managers
    thunar
    xfce4-exo

    # Launchers
    rofi

    # Clipboard
    wl-clipboard
    cliphist

    # Screenshots / Recording
    grim
    slurp
    grimblast
    wf-recorder
    gpu-screen-recorder
    gpu-screen-recorder-gtk

    # Media controls
    brightnessctl
    playerctl

    # Notifications
    libnotify

    # Search
    fsearch

    # Polkit
    polkit_gnome

    # Filesystems
    ntfs3g

    # Terminal
    wezterm

    # Video / Audio
    mpv

    # Creative
    blender
    kdePackages.kdenlive

    # Documents
    kdePackages.okular
    onlyoffice-desktopeditors

    # Images
    loupe
    #imv

    # Downloads
    parabolic

    # Volume
    pwvucontrol

    # Intel VAAPI
    intel-media-driver
    vpl-gpu-rt

blueman
bluetuith

# Quickshell dependencies
matugen
yq-go
zbar
mpvpaper
easyeffects
cava

# Quickshell ecosystem
quickshell
swayosd
networkmanagerapplet
hypridle
hyprlock
jq
socat
bc
acpi
iw
networkmanager
bluez
lm_sensors
python3

  ];
}