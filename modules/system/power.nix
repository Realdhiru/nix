{ lib, pkgs, ... }:
{
  # Generic sysctl kernel writeback (safe for all machines)
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
      # CPU & Performance Management (TLP as Sole Hardware Authority)
      CPU_SCALING_GOVERNOR_ON_AC  = "powersave";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_SAV = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC  = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_SAV = "power";

      CPU_BOOST_ON_AC  = 1;
      CPU_BOOST_ON_BAT = 1;
      CPU_BOOST_ON_SAV = 0;

      CPU_HWP_DYN_BOOST_ON_AC  = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 1;
      CPU_HWP_DYN_BOOST_ON_SAV = 0;

      PLATFORM_PROFILE_ON_AC  = "performance";
      PLATFORM_PROFILE_ON_BAT = "balanced";
      PLATFORM_PROFILE_ON_SAV = "balanced";

      CPU_MAX_PERF_ON_AC  = 100;
      CPU_MAX_PERF_ON_BAT = 100;
      CPU_MAX_PERF_ON_SAV = 60;

      RUNTIME_PM_ON_AC  = "auto";
      RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_SAV = "auto";

      PCIE_ASPM_ON_AC  = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";
      PCIE_ASPM_ON_SAV = "powersupersave";

      # NVMe Autonomous Power State Transitions (APST) on battery (~1.5W-2W SSD controller savings)
      NVME_APST_CHAR_ENABLE_ON_BAT = 1;
      AHCI_RUNTIME_PM_ON_BAT       = "auto";
      AHCI_RUNTIME_PM_TIMEOUT      = 15;

      # Disable the kernel NMI watchdog system-wide; TLP has no per-profile NMI setting.
      NMI_WATCHDOG = 0;

      # Sched powersave packs low-load tasks onto fewer cores so idle cores stay asleep
      SCHED_POWERSAVE_ON_BAT = 1;

      # Intel Iris Xe GPU Dynamic Frequency (downclocks when idle, full 1.45GHz burst on demand)
      INTEL_GPU_MIN_FREQ_ON_BAT   = 100;
      INTEL_GPU_MAX_FREQ_ON_BAT   = 1450;
      INTEL_GPU_BOOST_FREQ_ON_BAT = 1450;

      # boot.kernelParams keeps USB autosuspend disabled globally for the webcam;
      # keep TLP aligned so it does not re-enable autosuspend on battery.
      USB_AUTOSUSPEND = 0;

      # Wi-Fi Power Save
      WIFI_PWR_ON_AC  = "off";
      WIFI_PWR_ON_BAT = "on";
      WIFI_PWR_ON_SAV = "on";

      SOUND_POWER_SAVE_ON_AC      = 1;
      SOUND_POWER_SAVE_ON_BAT     = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      # Battery charge threshold managed by TLP directly
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0  = 80;
    };
  };

  # --- 4. LID SWITCH uaccess (event-driven lid watcher) ---
  # The lid switch is an input device (SW_LID) and emits NO kernel
  # uevent, so lid-monitor.sh reads it via evdev instead. Grant the
  # active session ACL access ONLY to this device: matched narrowly on
  # the PNP0C0D device path, so no other /dev/input/event* node is
  # affected. Never widen this to the input group or all event nodes.
  # This MUST be in a 70-* rules file so it is evaluated before systemd's
  # 71-seat.rules (which adds the seat tag) and 73-seat-late.rules (which
  # runs the uaccess builtin).
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "lid-uaccess-rule";
      destination = "/etc/udev/rules.d/70-lid-uaccess.rules";
      text = ''
        SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_PATH}=="pci-0000:00:1f.0-platform-PNP0C0D:01", ENV{ID_INPUT_SWITCH}=="1", TAG+="uaccess"
      '';
    })
  ];
}
