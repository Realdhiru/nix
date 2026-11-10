{ lib, pkgs, user, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.consoleMode = "max";

  boot.plymouth.enable = false;

  boot.consoleLogLevel = 3;

  boot.kernelParams = [
    "quiet"
    "bgrt_disable"
    "video=efifb:nobgrt"
    "fbcon=nodefer"
    "mem_sleep_default=deep"
    "rd.systemd.show_status=auto"
    "rd.udev.log_level=3"
  ]
  ++ lib.optional user.power.disableNmiWatchdog "nmi_watchdog=0"
  ++ lib.optional user.workarounds.disableUsbAutosuspend "usbcore.autosuspend=-1";

  boot.extraModprobeConfig = ''
    options uvcvideo nodrop=1
  '';

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.sysrq" = 4;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "fs.suid_dumpable" = 0;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  boot.supportedFilesystems = [ "ntfs" ];
}
