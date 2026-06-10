{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    #
    # CLI
    #
    vim
    wget
    git
    curl
    tree
    fastfetch
    btop
    weathr
    libva-utils

    #
    # Development
    #
    vscodium

    #
    # Browsers
    #
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    brave

    #
    # File Managers
    #
    thunar

    #
    # Launchers
    #
    rofi

    #
    # Clipboard
    #
    wl-clipboard
    cliphist
    nwg-clipman

    #
    # Screenshots / Recording
    #
    grim
    slurp
    grimblast
    wf-recorder
    gpu-screen-recorder
    gpu-screen-recorder-gtk

    #
    # Media controls
    #
    brightnessctl
    playerctl

    #
    # Notifications
    #
    libnotify

    #
    # Search
    #
    fsearch

    #
    # Polkit
    #
    polkit_gnome

    #
    # Filesystems
    #
    ntfs3g

    #
    # Terminal
    #
    wezterm

    #
    # Music
    #
    spotify

    #
    # Video / Audio
    #
    mpv

    #
    # Creative
    #
    blender
    kdePackages.kdenlive

    #
    # Documents
    #
    kdePackages.okular
    onlyoffice-desktopeditors

    #
    # Images
    #
    loupe
    imv

    #
    # Theme tools
    #
    lxappearance
    nwg-look
    nwg-icon-picker

    #
    # Displays
    #
    nwg-displays

    #
    # Downloads
    #
    parabolic

    #
    # Volume
    #
    pwvucontrol

    #
    # Intel VAAPI
    #
    intel-media-driver
    vpl-gpu-rt
  ];
}