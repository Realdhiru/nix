{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.consoleMode = "max";
  boot.plymouth.enable = false;
  boot.kernelParams = [
    "loglevel=3"
    #"rd.systemd.show_status=false"
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  networking.hostName = "nixos"; # Define your hostname.
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Kolkata";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  programs.hyprland.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";
  users.users.realdhiru = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ]; # Enable ‘sudo’ for the user.
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    curl
    tree
    fastfetch
    wezterm
    brave
    zed-editor
    xfce.thunar
    rofi
    wl-clipboard
    cliphist
    grim
    slurp
    brightnessctl
    playerctl
    ntfs3g
    libnotify
    nixd
    nixfmt-rfc-style
    fsearch
    kdePackages.dolphin
    polkit_gnome
  ];

  # Create a systemd user service for the Polkit Agent
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # Allow users in the wheel group to mount drives without a password prompt
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
             action.id == "org.freedesktop.udisks2.filesystem-mount-system") &&
            subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        }
    });
  '';

  services.getty.autologinUser = "realdhiru";
  services.power-profiles-daemon.enable = true;

  programs.thunar.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.upower.enable = true;
  security.polkit.enable = true;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;
  system.stateVersion = "25.11"; # Did you read the comment?

}
