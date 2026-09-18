{ config, pkgs, user, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./hardware/asus.nix
    ./hardware/sonix-webcam.nix
    ../../modules/system/boot.nix
    ../../modules/system/users.nix
    ../../modules/system/services.nix
    ../../modules/system/packages.nix
    ../../modules/system/fonts.nix
    ../../modules/system/power.nix
    ../../modules/system/gaming.nix
  ];

  # Host-specific Intel GPU Early KMS & fastboot
  boot.initrd.kernelModules = [ "i915" ];

  # Host-specific swapfile & hibernate resume device configuration
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];
  boot.resumeDevice = "/dev/disk/by-uuid/d0a20f82-2287-41fd-b017-617b84e4d4b6";
  boot.kernelParams = [
    "i915.fastboot=1"
    "resume_offset=39880704"
  ];

  # systemd.tmpfiles charge threshold rule removed —
  # TLP now manages this via START/STOP_CHARGE_THRESH_BAT0

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    NIXOS_OZONE_WL = "1";
  };

  environment.variables.GSETTINGS_SCHEMA_DIR =
  "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";

  programs.zsh.enable = true;
  networking.hostName = user.hostname;
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;
  time.timeZone = "Asia/Kolkata";
  time.hardwareClockInLocalTime = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  programs.hyprland.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";
  system.stateVersion = "25.11";
}