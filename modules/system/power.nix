# modules/system/power.nix
{ config, lib, pkgs, ... }:
{
  # --- 1. KERNEL-LEVEL POWER FIXES ---
  boot.kernelParams = [ "nmi_watchdog=0" ];
  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 6000;
  };

  # --- 2. POWER DAEMONS ---
  # Required for Quickshell UI to toggle performance profiles via powerprofilesctl
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      # Defer CPU management to power-profiles-daemon to prevent conflicts
      # TLP will exclusively manage PCIe, USB, and Battery Thresholds

      RUNTIME_PM_ON_AC  = "on";
      RUNTIME_PM_ON_BAT = "auto";

      PCIE_ASPM_ON_AC  = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # FIX: Prevent USB Bluetooth interface from dropping
      USB_AUTOSUSPEND = 0;
      USB_EXCLUDE_BTUSB = 1;
      USB_DENYLIST = "3554:fc00";

      # FIX: Prevent Wi-Fi interface from ignoring beacons
      WIFI_PWR_ON_AC  = "off";
      WIFI_PWR_ON_BAT = "off";

      SOUND_POWER_SAVE_ON_AC      = 0;
      SOUND_POWER_SAVE_ON_BAT     = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # Battery charge threshold managed by TLP directly
      # ASUS only accepts 40, 60, or 80 — 80 is confirmed working on this model
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0  = 80;
    };
  };

  # --- 3. ASUS CHARGER-CONNECTED PERFORMANCE FIX ---
  # When battery is capped at 80%, ASUS firmware reports power source as
  # "Battery" even though charger is physically connected.
  # These rules force TLP and power-profiles-daemon into AC/performance mode
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", \
      RUN+="${pkgs.tlp}/bin/tlp ac", \
      RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance"
      
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", \
      RUN+="${pkgs.tlp}/bin/tlp bat", \
      RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced"
  '';
}