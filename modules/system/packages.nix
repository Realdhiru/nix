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
    vscodium

    # Browser
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    brave

    # File managers
    thunar

    # Launcher
    rofi

    # Clipboard
    wl-clipboard
    cliphist

    # Screenshots
    grim
    slurp
    grimblast
    wf-recorder

    # Multimedia
    brightnessctl
    playerctl

    # Windows drives
    ntfs3g

    # Notifications
    libnotify

    # Search
    fsearch

    # Polkit agent
    polkit_gnome

    mpv
    blender
    kdePackages.kdenlive
    kdePackages.okular
    onlyoffice-desktopeditors
    spotify
    btop
    weathr
    loupe
    imv
    lxappearance
    nwg-look
    nwg-displays
    nwg-clipman
    nwg-icon-picker
    parabolic
    pwvucontrol
    gpu-screen-recorder
gpu-screen-recorder-gtk
  ];
}
