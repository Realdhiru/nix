{ lib, user, ... }:

let
  profileSettings = lib.filterAttrs (_: value: value != null) {
    PLATFORM_PROFILE_ON_AC = user.power.platformProfiles.ac;
    PLATFORM_PROFILE_ON_BAT = user.power.platformProfiles.battery;
    PLATFORM_PROFILE_ON_SAV = user.power.platformProfiles.saver;
  };

  batteryFirstSettings = lib.optionalAttrs user.power.balancedBatteryFirst {
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    CPU_BOOST_ON_BAT = 0;
    CPU_HWP_DYN_BOOST_ON_BAT = 0;
    INTEL_GPU_MAX_FREQ_ON_BAT = 1100;
    INTEL_GPU_BOOST_FREQ_ON_BAT = 1100;
  };
in
{
  # Generic writeback default.
  boot.kernel.sysctl."vm.dirty_writeback_centisecs" = 6000;

  # TLP is the primary declared profile manager.
  services.power-profiles-daemon.enable = lib.mkForce false;
  services.thermald.enable = lib.mkDefault true;
  services.tlp = {
    enable = true;
    settings = user.power.tlpSettings
      // profileSettings
      // batteryFirstSettings
      // {
        # Universal battery charge limits (TLP automatically applies to BAT0/BAT1)
        START_CHARGE_THRESH_BAT0 = lib.mkDefault 75;
        STOP_CHARGE_THRESH_BAT0 = lib.mkDefault 80;
        START_CHARGE_THRESH_BAT1 = lib.mkDefault 75;
        STOP_CHARGE_THRESH_BAT1 = lib.mkDefault 80;

        NMI_WATCHDOG = if user.power.disableNmiWatchdog then 0 else 1;
        USB_AUTOSUSPEND = if user.workarounds.disableUsbAutosuspend then 0 else 1;
        USB_DENYLIST = "3277:0022";
        USB_EXCLUDE_AUDIO = 1;
        USB_EXCLUDE_BTUSB = 1;
      };
  };

  # The desktop profile UI can call TLP without password prompts
  security.sudo.extraRules = [
    {
      users = [ user.username ];
      commands = map (profile: {
        command = "/run/current-system/sw/bin/tlp ${profile}";
        options = [ "NOPASSWD" ];
      }) [ "performance" "balanced" "power-saver" "start" ];
    }
  ];
}
