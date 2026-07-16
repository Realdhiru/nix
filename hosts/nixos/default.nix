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
    ../../modules/system/power.nix
  ];

  boot.kernelParams = [
    "ahci.mobile_lpm_policy=3"
    "pcie_aspm=force"
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
  };

  environment.systemPackages = with pkgs; [
    psmisc
    curl
    file
  ];

  programs.zsh.enable = true;
  networking.hostName = "vivobook";
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Kolkata";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  
  programs.hyprland = {
  enable = true;

  plugins = [
    pkgs.hyprexpo-plugin
  ];
};
  i18n.defaultLocale = "en_US.UTF-8";
  system.stateVersion = "25.11";
}