{ config, lib, pkgs, ... }:
{
  # --- 1. KERNEL-LEVEL POWER FIXES ---
  boot.kernelParams = [ "nmi_watchdog=0" ];
  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 6000;
  };

  # --- 2. TLP CONFIGURATION (SOLE POWER MANAGER) ---
  # NixOS strictly forbids running both TLP and power-profiles-daemon
  services.power-profiles-daemon.enable = lib.mkForce false;
  services.thermald.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      # CPU & Performance Management (Restored to TLP)
      CPU_SCALING_GOVERNOR_ON_AC  = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC  = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_BOOST_ON_AC  = 1;
      CPU_BOOST_ON_BAT = 0;

      PLATFORM_PROFILE_ON_AC  = "performance";
      PLATFORM_PROFILE_ON_BAT = "quiet";

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
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0  = 80;
    };
  };

  # --- 3. ASUS CHARGER-CONNECTED PERFORMANCE FIX ---
  # When battery is capped at 80%, ASUS firmware reports power source as
  # "Battery" even though charger is physically connected.
  # These rules force TLP into AC/performance mode natively.
  #
  # This udev rule is the SOLE authority for tlp ac/bat switching in the
  # entire system. The Quickshell BatteryPopup.qml power-profile picker
  # intentionally does NOT call `tlp ac`/`tlp bat` itself — it only manages
  # per-core EPP (via set_epp.sh) and CPU turbo/boost, both of which are
  # orthogonal to AC/BAT mode. (power-profiles-daemon is force-disabled
  # above, so `powerprofilesctl` is never used anywhere in this config.)
  # Do not re-add a `tlp ac`/`tlp bat` call anywhere else; it would
  # silently race against this rule.
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", \
      RUN+="${pkgs.tlp}/bin/tlp ac"

    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", \
      RUN+="${pkgs.tlp}/bin/tlp bat"
  '';
}