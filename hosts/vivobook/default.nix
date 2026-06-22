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

  systemd.tmpfiles.rules = [
    "w /sys/class/power_supply/BAT0/charge_control_end_threshold - - - - 80"
  ];

  # Enable hardware graphics acceleration and Intel media drivers for Iris Xe
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # Modern iHD driver for Raptor Lake / Iris Xe
      intel-vaapi-driver # Fallback compatibility layer
      libvdpau-va-gl
    ];
  };

  # Set driver variables globally for media encoding/decoding engines
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

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
  system.stateVersion = "25.11";
}