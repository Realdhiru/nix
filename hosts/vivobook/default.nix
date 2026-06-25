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

  # --- HARDWARE POWER OPTIMIZATION (PHASE 4) ---
  # Enforces aggressive sleep states down to storage planes and PCIe buses
  boot.kernelParams = [
    "ahci.mobile_lpm_policy=3" 
    "pcie_aspm=force"          
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

  # --- CRITICAL SYSTEM DEPENDENCIES ---
  # Installs psmisc (killall) to stop hung wallpaper and QuickShell loops
  environment.systemPackages = with pkgs; [
    psmisc
    curl
    file
  ];

  programs.zsh.enable = true;

  # FIXED: Aligned hostName string to match your flake build descriptor target (vivobook)
  networking.hostName = "vivobook";
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