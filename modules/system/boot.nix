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
    "nmi_watchdog=0"
  ];

  boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
  boot.kernel.sysctl = {
  "kernel.kptr_restrict" = 2;
  "kernel.dmesg_restrict" = 1;
  "kernel.sysrq" = 0;
  "kernel.unprivileged_bpf_disabled" = 1;
  "net.core.bpf_jit_harden" = 2;
  "net.ipv4.conf.all.log_martians" = 1;
  "net.ipv4.conf.default.log_martians" = 1;
  "net.ipv4.conf.all.rp_filter" = 1;
  "net.ipv4.conf.all.accept_redirects" = 0;
  "net.ipv4.conf.default.accept_redirects" = 0;
  "net.ipv4.conf.all.send_redirects" = 0;
  "net.ipv6.conf.all.accept_redirects" = 0;
  "net.ipv6.conf.default.accept_redirects" = 0;
  "fs.protected_fifos" = 2;
  "fs.protected_regular" = 2;
  "fs.suid_dumpable" = 0;
};
}