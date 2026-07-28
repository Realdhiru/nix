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
    ../../modules/system/gaming.nix

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

  environment.variables.GSETTINGS_SCHEMA_DIR =
  "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";

  programs.zsh.enable = true;
  networking.hostName = "vivobook";
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;
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