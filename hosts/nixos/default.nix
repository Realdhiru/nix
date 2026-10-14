{ config, pkgs, user, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./hardware/asus.nix
    ../../modules/system/boot.nix
    ../../modules/system/users.nix
    ../../modules/system/services.nix
    ../../modules/system/packages.nix
    ../../modules/system/fonts.nix
    ../../modules/system/power.nix
    ../../modules/system/gaming.nix
  ];

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
  networking.hostName = user.hostname;
  networking.networkmanager = {
    enable = true;
    settings = {
      connectivity = {
        uri = "http://connectivity-check.ubuntu.com/check_network_status.txt";
        interval = 30;
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
          CURRENT_CON=$(${pkgs.networkmanager}/bin/nmcli -t -f GENERAL.CONNECTION dev show "$WIFI_IFACE" 2>/dev/null | cut -d: -f2)

          # Extract all saved wifi connection profiles (strictly previously saved/connected)
          SAVED_PROFILES=$(${pkgs.networkmanager}/bin/nmcli -t -f NAME,TYPE connection show | ${pkgs.gawk}/bin/awk -F: '$2=="802-11-wireless"{print $1}')
          [ -n "$SAVED_PROFILES" ] || exit 0

          # Find currently broadcasting SSIDs sorted by signal strength (descending)
          CANDIDATES=$(${pkgs.networkmanager}/bin/nmcli -t -f SSID,SIGNAL dev wifi list 2>/dev/null | sort -t: -k2 -nr | cut -d: -f1 | awk '!seen[$0]++')

          for candidate in $CANDIDATES; do
            [ -n "$candidate" ] || continue
            [ "$candidate" = "$CURRENT_CON" ] && continue

            # Verify candidate matches a saved, known profile
            MATCH=""
            while IFS= read -r saved; do
              if [ "$saved" = "$candidate" ]; then
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
  time.timeZone = "Asia/Kolkata";
  time.hardwareClockInLocalTime = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  programs.hyprland.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";
  system.stateVersion = "25.11";
}