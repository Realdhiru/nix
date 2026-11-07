{
  # Identity and personal defaults. Machine facts belong in hosts/<host>/system.nix.
  username = "realdhiru";
  name = "D";
  homeDirectory = "/home/realdhiru";

  timeZone = "Asia/Kolkata";
  locale = "en_US.UTF-8";
  hardwareClockInLocalTime = true;
  keyboard = {
    layout = "us";
    options = "grp:alt_shift_toggle";
  };

  desktop = {
    terminal = "alacritty";
    browser = "brave";
    editor = "gram";
    fileManager = "pcmanfm-qt";
    repositoryDirectory = "nix";
    wallpaperDirectory = "Pictures/Wallpapers";
    wallpaperOrganizerProjectsDirectory = "Projects/Wallpapers";
    themeMode = "dark";
    refreshRate = { ac = 120; battery = 60; };
  };

  audio = {
    # Preserve the user's internal-speaker keep-awake behavior; its idle power
    # cost is a measurement item, not an unattended configuration change.
    keepInternalSpeakerAwake = true;
  };

  power = {
    disableNmiWatchdog = true;
    # Optional battery-first tuning while the named profile remains Balanced.
    # Off preserves the current balanced EPP/boost feel on battery.
    balancedBatteryFirst = false;
    # User-selected TLP behavior. The host module adds only detected hardware
    # settings (battery name, Intel GPU controls, supported platform profiles).
    platformProfiles = {
      ac = "performance";
      battery = "balanced";
      saver = "balanced";
    };
    tlpSettings = {
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_SAV = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_SAV = "power";

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 1;
      CPU_BOOST_ON_SAV = 0;

      CPU_HWP_DYN_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 1;
      CPU_HWP_DYN_BOOST_ON_SAV = 0;

      CPU_MAX_PERF_ON_AC = 100;
      CPU_MAX_PERF_ON_BAT = 100;
      CPU_MAX_PERF_ON_SAV = 60;

      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_SAV = "auto";

      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";
      PCIE_ASPM_ON_SAV = "powersupersave";

      NVME_APST_CHAR_ENABLE_ON_BAT = 1;
      AHCI_RUNTIME_PM_ON_BAT = "auto";
      AHCI_RUNTIME_PM_TIMEOUT = 15;

      SCHED_POWERSAVE_ON_BAT = 1;

      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";
      WIFI_PWR_ON_SAV = "on";

      SOUND_POWER_SAVE_ON_AC = 1;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";
    };
  };

  workarounds = {
    # Workaround from 376a0b9 (2026-09-18): keep USB autosuspend disabled
    # after webcam streaming failures. Removal test: only revisit after the
    # user asks to diagnose the camera and can retest it. Both the kernel
    # parameter and TLP setting are derived from this one choice.
    disableUsbAutosuspend = true;
  };
}
