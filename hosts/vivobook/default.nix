{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/system/boot.nix
    ../../modules/system/users.nix
    ../../modules/system/audio.nix
    ../../modules/system/services.nix
    ../../modules/system/packages.nix
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

  system.stateVersion = "25.11";
}
