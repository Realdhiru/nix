{ lib, user, hostFacts, ... }:

let
  chooseProfile = requested:
    if builtins.elem requested hostFacts.platformProfileChoices then requested
    else if builtins.elem "balanced" hostFacts.platformProfileChoices then "balanced"
    else null;

  profileSettings = lib.filterAttrs (_: value: value != null) {
    PLATFORM_PROFILE_ON_AC = chooseProfile user.power.platformProfiles.ac;
    PLATFORM_PROFILE_ON_BAT = chooseProfile user.power.platformProfiles.battery;
    PLATFORM_PROFILE_ON_SAV = chooseProfile user.power.platformProfiles.saver;
  };

  intelGpuSettings = if builtins.elem "intel" hostFacts.gpuVendors
    && hostFacts.intelGpuBatteryFrequencies != null then {
      INTEL_GPU_MIN_FREQ_ON_BAT = hostFacts.intelGpuBatteryFrequencies.min;
      INTEL_GPU_MAX_FREQ_ON_BAT = hostFacts.intelGpuBatteryFrequencies.max;
      INTEL_GPU_BOOST_FREQ_ON_BAT = hostFacts.intelGpuBatteryFrequencies.boost;
    } else { };

  batterySettings = lib.optionalAttrs (hostFacts.hasBattery
    && hostFacts.batteryName != ""
    && hostFacts.chargeThresholds != null) {
    "START_CHARGE_THRESH_${hostFacts.batteryName}" = hostFacts.chargeThresholds.start;
    "STOP_CHARGE_THRESH_${hostFacts.batteryName}" = hostFacts.chargeThresholds.stop;
  };
  batteryFirstSettings = lib.optionalAttrs user.power.balancedBatteryFirst {
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    CPU_BOOST_ON_BAT = 0;
    CPU_HWP_DYN_BOOST_ON_BAT = 0;
  } // lib.optionalAttrs (user.power.balancedBatteryFirst && builtins.elem "intel" hostFacts.gpuVendors) {
    INTEL_GPU_MAX_FREQ_ON_BAT = 1100;
    INTEL_GPU_BOOST_FREQ_ON_BAT = 1100;
  };
in
{
  # Generic writeback default. Hardware and personal power policy are passed
  # separately through hostFacts and user.nix.
  boot.kernel.sysctl."vm.dirty_writeback_centisecs" = 6000;

  # TLP is the only declared profile writer. A batteryless host gets no
  # laptop power daemon; capability facts are generated into system.nix.
  services.power-profiles-daemon.enable = lib.mkForce false;
  services.thermald.enable = hostFacts.cpuVendor == "intel";
  services.tlp = {
    enable = hostFacts.hasBattery;
    settings = user.power.tlpSettings
      // profileSettings
      // intelGpuSettings
      // batterySettings
      // batteryFirstSettings
      // {
        NMI_WATCHDOG = if user.power.disableNmiWatchdog then 0 else 1;
        USB_AUTOSUSPEND = if user.workarounds.disableUsbAutosuspend then 0 else 1;
      };
  };

  # The desktop profile UI can call TLP without a password only on hosts
  # where the battery-backed TLP service is enabled.
  security.sudo.extraRules = lib.optionals hostFacts.hasBattery [
    {
      users = [ user.username ];
      commands = map (profile: {
        command = "/run/current-system/sw/bin/tlp ${profile}";
        options = [ "NOPASSWD" ];
      }) [ "performance" "balanced" "power-saver" "start" ];
    }
  ];
}
