{ pkgs, ... }:

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
  ];
}
