# modules/system/power.nix
{ config, lib, pkgs, ... }:
{
  # --- 1. KERNEL-LEVEL POWER FIXES ---
  boot.kernelParams = [ "nmi_watchdog=0" ];
  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 6000;
  };

  # --- 2. TLP CONFIGURATION ---
  # Disables power-profiles-daemon which conflicts with TLP.
  # services.nix still declares it as enabled — mkForce wins.
  services.power-profiles-daemon.enable = lib.mkForce false;
  services.thermald.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC  = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC  = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_BOOST_ON_AC  = 1;
      CPU_BOOST_ON_BAT = 0;

      # Valid choices confirmed from /sys/firmware/acpi/platform_profile_choices:
      # quiet, balanced, performance — "low-power" does not exist on this firmware
      PLATFORM_PROFILE_ON_AC  = "performance";
      PLATFORM_PROFILE_ON_BAT = "quiet";

      RUNTIME_PM_ON_AC  = "on";
      RUNTIME_PM_ON_BAT = "auto";

      PCIE_ASPM_ON_AC  = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      USB_AUTOSUSPEND = 1;
      # Confirmed via lsusb: 3554:fc00 = Compx 2.4G Receiver
      # Excluded from autosuspend to prevent input lag
      USB_DENYLIST = "3554:fc00";

      WIFI_PWR_ON_AC  = "off";
      WIFI_PWR_ON_BAT = "on";

      SOUND_POWER_SAVE_ON_AC      = 0;
      SOUND_POWER_SAVE_ON_BAT     = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";
    };
  };
}