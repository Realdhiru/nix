{ config, lib, pkgs, ... }:

{

--- 1. KERNEL-LEVEL POWER FIXES ---

boot.kernelParams = [ "nmi_watchdog=0" ];
boot.kernel.sysctl = { "vm.dirty_writeback_centisecs" = 6000; };

--- 2. INTEL THERMAL MANAGEMENT ---

Essential for Intel 13th Gen (i5-13500H) to prevent overheating and battery drain

services.thermald.enable = true;

--- 3. TLP CONFIGURATION ---

We use mkForce to brutally override PPD if it is accidentally enabled somewhere else in your dotfiles

services.power-profiles-daemon.enable = lib.mkForce false;

services.tlp = {
enable = true;
settings = {
# CPU Governors
CPU_SCALING_GOVERNOR_ON_AC = "performance";
CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

  CPU_BOOST_ON_AC = 1;
  CPU_BOOST_ON_BAT = 0;
  
  # Asus Platform Profiles
  PLATFORM_PROFILE_ON_AC = "performance";
  PLATFORM_PROFILE_ON_BAT = "quiet";
  
  # Aggressive PCIe and Device Sleep
  RUNTIME_PM_ON_AC = "on";
  RUNTIME_PM_ON_BAT = "auto";
  PCIE_ASPM_ON_AC = "default";
  PCIE_ASPM_ON_BAT = "powersupersave";
  
  # USB Suspend (with your 2.4Ghz Receiver excluded so your mouse doesn't disconnect)
  USB_AUTOSUSPEND = 1;
  USB_DENYLIST = "3554:fc00";
  
  # Network & Audio Sleep
  WIFI_PWR_ON_AC = "off";
  WIFI_PWR_ON_BAT = "on";
  SOUND_POWER_SAVE_ON_AC = 0;
  SOUND_POWER_SAVE_ON_BAT = 1;
  SOUND_POWER_SAVE_CONTROLLER = "Y";
};


};
}