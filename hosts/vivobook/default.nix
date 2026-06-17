{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/system/boot.nix
    ../../modules/system/users.nix
    ../../modules/system/services.nix
    ../../modules/system/packages.nix
    ../../modules/system/fonts.nix
    ../../modules/system/memory.nix
  ];

  programs.zsh.enable = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Kolkata";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  programs.hyprland.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";

  # Prevent home-manager early activation mismatches from throwing boot warnings
  systemd.services."home-manager-realdhiru" = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  system.stateVersion = "25.11";
}