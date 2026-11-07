{ config, pkgs, user, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/boot.nix
    ../../modules/system/users.nix
    ../../modules/system/services.nix
    ../../modules/system/packages.nix
    ../../modules/system/fonts.nix
    ../../modules/system/power.nix
    ../../modules/system/gaming.nix
  ];

  # Facts detected for this machine; capability detection is generation-time
  # data, never an impure Nix evaluation. init-host writes this record for new
  # hosts and does not overwrite an existing one.
  _module.args.hostFacts = {
    cpuVendor = "intel";
    gpuVendors = [ "intel" ];
    hasBattery = true;
    batteryName = "BAT0";
    chargeThresholds = { start = 75; stop = 80; };
    platformProfileChoices = [ "quiet" "balanced" "performance" ];
    intelGpuBatteryFrequencies = { min = 100; max = 1450; boost = 1450; };
  };

  # Host-specific Intel GPU Early KMS & fastboot
  boot.initrd.kernelModules = [ "i915" ];

  # Host-specific swapfile & hibernate resume device configuration
  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];
  boot.resumeDevice = "/dev/disk/by-uuid/d0a20f82-2287-41fd-b017-617b84e4d4b6";
  boot.kernelParams = [
    "i915.fastboot=1"
    "i915.enable_fbc=1"
    "i915.enable_psr=1"
    "resume_offset=39880704"
  ];

  # systemd.tmpfiles charge threshold rule removed —
  # TLP now manages this via START/STOP_CHARGE_THRESH_BAT0

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    NIXOS_OZONE_WL = "1";
  };

  environment.variables.GSETTINGS_SCHEMA_DIR =
    "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";

  programs.zsh.enable = true;
  networking.hostName = "NixOS";
  networking.networkmanager = {
    enable = true;
    settings = {
      connectivity = {
        uri = "http://connectivity-check.ubuntu.com/check_network_status.txt";
        interval = 300;
      };
      connection = {
        "wifi.powersave" = 3;
      };
      device = {
        "wifi.scan-rand-mac-address" = "no";
      };
    };
    dispatcherScripts = [
      {
        source = pkgs.writeShellScript "wifi-failover" ''
          # Only react on connectivity change events
          [ "$2" = "connectivity-change" ] || exit 0

          # Only take action if connectivity is lost or limited
          case "$CONNECTIVITY_STATE" in
            LIMITED|NONE) ;;
            *) exit 0 ;;
          esac

          # Prevent rapid failover flapping (enforce 25s debounce cooldown)
          LOCK_DIR="/run/nm-wifi-failover"
          mkdir -p "$LOCK_DIR"
          STAMP_FILE="$LOCK_DIR/last_switch"
          NOW=$(date +%s)
          if [ -f "$STAMP_FILE" ]; then
            LAST=$(cat "$STAMP_FILE" 2>/dev/null || echo 0)
            if [ $((NOW - LAST)) -lt 25 ]; then
              exit 0
            fi
          fi

          # Find active wireless interface
          WIFI_IFACE=$(${pkgs.networkmanager}/bin/nmcli -t -f DEVICE,TYPE device status | ${pkgs.gawk}/bin/awk -F: '$2=="wifi"{print $1; exit}')
          [ -n "$WIFI_IFACE" ] || exit 0

          # Get currently active connection on that wifi interface
          CURRENT_CON=$(${pkgs.networkmanager}/bin/nmcli -g GENERAL.CONNECTION dev show "$WIFI_IFACE" 2>/dev/null | head -n1)
          CURRENT_SSID=""
          [ -z "$CURRENT_CON" ] || CURRENT_SSID=$(${pkgs.networkmanager}/bin/nmcli -g 802-11-wireless.ssid connection show "$CURRENT_CON" 2>/dev/null | head -n1)

          # Extract all saved wifi connection profiles (strictly previously saved/connected)
          SAVED_PROFILES=$(${pkgs.networkmanager}/bin/nmcli -t -f NAME,TYPE connection show | ${pkgs.gawk}/bin/awk -F: '$2=="802-11-wireless"{print $1}')
          [ -n "$SAVED_PROFILES" ] || exit 0

          # Find currently broadcasting SSIDs from cached list without triggering active RF scan
          CANDIDATES=$(${pkgs.networkmanager}/bin/nmcli -t -f SSID,SIGNAL dev wifi list --rescan no 2>/dev/null | sort -t: -k2 -nr | cut -d: -f1 | awk '!seen[$0]++')

          for candidate in $CANDIDATES; do
            [ -n "$candidate" ] || continue
            [ "$candidate" = "$CURRENT_SSID" ] && continue

            # Verify candidate matches a saved, known profile
            MATCH=""
            while IFS= read -r saved; do
              SAVED_SSID=$(${pkgs.networkmanager}/bin/nmcli -g 802-11-wireless.ssid connection show "$saved" 2>/dev/null | head -n1)
              if [ "$SAVED_SSID" = "$candidate" ]; then
                MATCH="$saved"
                break
              fi
            done <<< "$SAVED_PROFILES"

            if [ -n "$MATCH" ]; then
              # Attempt clean switch to the saved alternative
              if ${pkgs.networkmanager}/bin/nmcli -w 8 connection up "$MATCH" >/dev/null 2>&1; then
                echo "$NOW" > "$STAMP_FILE"
                exit 0
              fi
            fi
          done
        '';
        type = "basic";
      }
    ];
  };
  systemd.services.NetworkManager-wait-online.enable = false;
  time.timeZone = user.timeZone;
  time.hardwareClockInLocalTime = user.hardwareClockInLocalTime;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  programs.hyprland.enable = true;
  i18n.defaultLocale = user.locale;
  system.stateVersion = "25.11";

  # ASUS Linux daemon is enabled only for the 80% charge ceiling.
  # Firmware profile switching and EPP linking remain disabled so TLP is the
  # only profile writer.
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
          platform_profile_on_battery: Balanced,
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
          bat_profile: Balanced,
          boot_sound: false,
          panel_od: false,
          mini_led_mode: false,
          animatrix_mode: Off,
          screenpad_brightness: 0,
      )
    '';
  };

  # ASUS Vivobook S15 OLED (K5504VA) brightness-key rebind after
  # critical-battery hybrid-sleep. Keep this host workaround local.
  systemd.services."systemd-hybrid-sleep".serviceConfig.ExecStartPost = [
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

  # The Raptor Lake Thunderbolt controllers are kept out of aggressive
  # runtime PM after observed USBSTS 0x401 resume failures.
  services.tlp.settings.RUNTIME_PM_DENYLIST = "00:0d.0 00:0d.3";

  # ASUS/ACPI lid switch uaccess is specific to this host's PNP0C0D path.
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
