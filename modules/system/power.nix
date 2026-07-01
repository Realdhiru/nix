{ config, lib, pkgs, ... }:

{

--- 1. KERNEL-LEVEL POWER FIXES ---

Disable NMI watchdog to reduce CPU wakeups

boot.kernelParams = [ "nmi_watchdog=0" ];

Increase VM writeback timeout.

6000 centisecs = 60 seconds (Wait longer before writing dirty pages to disk, letting NVMe sleep)

boot.kernel.sysctl = {
"vm.dirty_writeback_centisecs" = 6000;
};

--- 2. TLP CONFIGURATION ---

We must explicitly disable PPD as it conflicts with TLP.

services.power-profiles-daemon.enable = false;

services.tlp = {
enable = true;
settings = {
# CPU Governors & Energy Policy
CPU_SCALING_GOVERNOR_ON_AC = "performance";
CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

  # Boost Control (Set to 0 on BAT per spec, adjust to 1 if UI feels sluggish)
  CPU_BOOST_ON_AC = 1;
  CPU_BOOST_ON_BAT = 0;
  
  # Hardware Platform Profiles (Specific to ASUS firmware options)
  PLATFORM_PROFILE_ON_AC = "performance";
  PLATFORM_PROFILE_ON_BAT = "quiet";
  
  # PCIe & Device Runtime Power Management
  RUNTIME_PM_ON_AC = "on";
  RUNTIME_PM_ON_BAT = "auto";
  
  # PCIe Active State Power Management
  PCIE_ASPM_ON_AC = "default";
  PCIE_ASPM_ON_BAT = "powersupersave";
  
  # USB Suspend (Requires ID for the 2.4Ghz receiver below)
  USB_AUTOSUSPEND = 1;
  # USB_DENYLIST = "XXXX:XXXX"; # TODO: Insert 2.4Ghz receiver ID here
  
  # Network & Audio
  WIFI_PWR_ON_AC = "off";
  WIFI_PWR_ON_BAT = "on";
  SOUND_POWER_SAVE_ON_AC = 0;
  SOUND_POWER_SAVE_ON_BAT = 1;
  SOUND_POWER_SAVE_CONTROLLER = "Y";
};


};
}