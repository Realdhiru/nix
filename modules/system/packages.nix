{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    # CLI & Core Utilities
    vim git curl wget tree jq yq-go bc socat python3 btop weathr

    # Development & Terminal
    vscodium
    wezterm
    fastfetch

    # Browsers
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    
    # POWER OPTIMIZATION: Hardware-accelerated Brave override
    (brave.override { commandLineArgs = "--enable-features=VaapiVideoDecodeLinuxGL --use-gl=angle"; })

    # File Management
    fsearch ntfs3g xfce4-exo

    # Launchers & Clipboard
    rofi wl-clipboard cliphist

    # Screenshots & Recording
    grim slurp grimblast wf-recorder gpu-screen-recorder gpu-screen-recorder-gtk

    # Media & Display
    mpv mpvpaper awww playerctl brightnessctl easyeffects cava loupe ffmpeg imagemagick zbar

    # Documents & Creative
    kdePackages.okular onlyoffice-desktopeditors blender kdePackages.kdenlive parabolic

    # Audio & Networking
    pwvucontrol networkmanagerapplet blueman bluetuith

    # Power & Sensors
    acpi iw lm_sensors

    # Desktop Integration
    libnotify polkit_gnome hypridle hyprlock quickshell qt6Packages.qtmultimedia matugen

    powertop psmisc hyprsunset nodejs banner
  ];
}