{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.consoleMode = "max";

  boot.plymouth.enable = false;

  boot.kernelParams = [
    "loglevel=3"
  ];

  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
}
