{ pkgs, ... }:

{
  # Hardware Quirk: ASUS Vivobook / ROG platform tools & workarounds

  # 1. ASUS Linux daemon (asusd)
  # Used strictly for hardware battery ceiling enforcement (80%).
  # Platform-profile switching & EPP linking are disabled so TLP is sole authority.
  services.asusd.enable = true;
  systemd.services.asusd.restartIfChanged = false;
  systemd.services.asus-shutdown.restartIfChanged = false;

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
        profile_performance_epp: Performance,
        profile_quiet_fan_preset: Quiet,
        profile_balanced_fan_preset: Balanced,
        profile_performance_fan_preset: Performance,
        armoury_panel_profile_quiet: Quiet,
        armoury_panel_profile_balanced: Balanced,
        armoury_panel_profile_performance: Performance,
        ac_profile: Performance,
        bat_profile: Quiet,
        boot_sound: false,
        panel_od: false,
        mini_led_mode: false,
        animatrix_mode: Off,
        screenpad_brightness: 0,
    )
    '';
  };

  # 2. ASUS Vivobook S15 OLED (K5504VA) Brightness Rebind Workaround
  # After critical-battery hybrid-sleep, Fn brightness keys stop delivering ACPI
  # notifications until acpi.video_bus.0 is unbound and rebound.
  systemd.services."systemd-hybrid-sleep" = {
    serviceConfig.ExecStartPost = [
      (pkgs.writeShellScript "asus-brightness-rebind" ''
        set -u
        d=/sys/bus/auxiliary/drivers/video
        if [ ! -d "$d" ]; then
          exit 0
        fi
        echo "asus-brightness-rebind: re-arming acpi.video_bus.0 after hybrid-sleep"
        echo acpi.video_bus.0 > "$d"/unbind 2>/dev/null || true
        echo acpi.video_bus.0 > "$d"/bind 2>/dev/null || true
      '')
    ];
  };
}
