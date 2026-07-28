{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.consoleMode = "max";

  boot.plymouth.enable = false;

  boot.kernelParams = [
    "loglevel=3"
    "ahci.mobile_lpm_policy=3"
    "pcie_aspm=force"
  ];

  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
}