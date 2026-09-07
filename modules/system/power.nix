{ lib, pkgs, ... }:
{
  # --- 1. KERNEL-LEVEL POWER FIXES ---
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

      CPU_ENERGY_PERF_POLICY_ON_AC  = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_ENERGY_PERF_POLICY_ON_SAV = "power";

      CPU_BOOST_ON_AC  = 1;
      CPU_BOOST_ON_BAT = 0;
      CPU_BOOST_ON_SAV = 0;

      CPU_HWP_DYN_BOOST_ON_AC  = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;
      CPU_HWP_DYN_BOOST_ON_SAV = 0;

      PLATFORM_PROFILE_ON_AC  = "performance";
      PLATFORM_PROFILE_ON_BAT = "quiet";
      PLATFORM_PROFILE_ON_SAV = "quiet";

      RUNTIME_PM_ON_AC  = "on";
      RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_ON_SAV = "auto";

      PCIE_ASPM_ON_AC  = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";
      PCIE_ASPM_ON_SAV = "powersupersave";

      # FIX: Prevent USB Bluetooth interface from dropping
      USB_AUTOSUSPEND = 1;
      USB_AUTOSUSPEND_DISABLE_ON_AC = 1;
      USB_EXCLUDE_BTUSB = 1;
      USB_DENYLIST = "3554:fc00";

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

  services.asusd.enable = true;
  systemd.services.asusd.restartIfChanged = false;
  systemd.services.asus-shutdown.restartIfChanged = false;

  # Disable asusd platform-profile switching & EPP linking so TLP is sole authority
  environment.etc."asusd/asusd.ron" = {
    mode = "0644";
    text = ''
    (
        charge_control_end_threshold: 80,
        base_charge_control_end_threshold: 80,
        disable_nvidia_powerd_on_battery: true,
        ac_command: "",
        bat_command: "",
        platform_profile_linked_epp: false,
        platform_profile_on_battery: Quiet,
        change_platform_profile_on_battery: false,
        platform_profile_on_ac: Performance,
        change_platform_profile_on_ac: false,
        profile_quiet_epp: Power,
        profile_balanced_epp: BalancePerformance,
        profile_custom_epp: Performance,
        profile_performance_epp: Performance,
        ac_profile_tunings: {
            Performance: (
                enabled: false,
                group: {},
            ),
        },
        dc_profile_tunings: {
            Quiet: (
                enabled: false,
                group: {},
            ),
        },
        armoury_settings: {},
    )
  '';
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
    SUBSYSTEM=="power_supply", KERNEL=="ucsi-source-psy-USBC000:001", ATTR{online}=="1", \
      RUN+="${pkgs.tlp}/bin/tlp ac"

    SUBSYSTEM=="power_supply", KERNEL=="ucsi-source-psy-USBC000:001", ATTR{online}=="0", \
      RUN+="${pkgs.tlp}/bin/tlp bat"
  '';
  
}