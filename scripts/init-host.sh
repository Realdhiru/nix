#!/usr/bin/env bash
set -euo pipefail

fail() { printf 'init-host: %s\n' "$*" >&2; exit 1; }

root="$PWD"
[[ -f "$root/flake.nix" ]] || fail "run this from the repository root"

host_name="${1:-$(cat /etc/hostname 2>/dev/null || hostname)}"
host_dir_name="${host_name,,}"
[[ "$host_dir_name" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || fail "invalid host name: $host_name"
target="$root/hosts/$host_dir_name"

if [[ -e "$target/system.nix" || -e "$target/hardware-configuration.nix" ]]; then
  fail "refusing to overwrite $target; inspect or remove its existing host files manually"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
nixos-generate-config --show-hardware-config > "$tmp/hardware-configuration.nix"
[[ -s "$tmp/hardware-configuration.nix" ]] || fail "nixos-generate-config returned an empty hardware configuration"

read_file() {
  local path="$1" fallback="$2"
  if [[ -r "$path" ]]; then cat "$path"; else printf '%s' "$fallback"; fi
}

cpu_raw=$(awk -F ': *' '/^vendor_id/ { print $2; exit }' /proc/cpuinfo 2>/dev/null || true)
case "$cpu_raw" in
  GenuineIntel) cpu_vendor=intel ;;
  AuthenticAMD) cpu_vendor=amd ;;
  *) cpu_vendor=unknown ;;
esac

gpu_vendors=()
while IFS= read -r vendor_id; do
  case "$vendor_id" in
    8086) gpu_vendors+=(intel) ;;
    1002) gpu_vendors+=(amd) ;;
    10de) gpu_vendors+=(nvidia) ;;
  esac
done < <(lspci -n 2>/dev/null | awk '$2 ~ /^03/ { split($3, id, ":"); print id[1] }' | sort -u)

battery_name=""
for type_path in /sys/class/power_supply/*/type; do
  [[ -r "$type_path" ]] || continue
  read -r supply_type < "$type_path" || true
  if [[ "$supply_type" == Battery ]]; then
    battery_name="${type_path%/type}"
    battery_name="${battery_name##*/}"
    break
  fi
done
if [[ -n "$battery_name" ]]; then has_battery=true; else has_battery=false; fi

platform_profiles=()
if [[ -r /sys/firmware/acpi/platform_profile_choices ]]; then
  read -r -a platform_profiles < /sys/firmware/acpi/platform_profile_choices || true
fi

panel_names=()
panel_modes=()
for connector in /sys/class/drm/card*-eDP-* /sys/class/drm/card*-LVDS-* /sys/class/drm/card*-DSI-*; do
  [[ -d "$connector" ]] || continue
  name="${connector##*/}"
  name="${name#*-}"
  panel_names+=("$name")
  if [[ -r "$connector/modes" ]]; then
    while IFS= read -r mode; do [[ -n "$mode" ]] && panel_modes+=("$name:$mode"); done < "$connector/modes"
  fi
done

cpu_driver=""
for driver_path in /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver /sys/devices/system/cpu/cpufreq/policy0/scaling_driver; do
  if [[ -r "$driver_path" ]]; then read -r cpu_driver < "$driver_path"; break; fi
done

gpu_min="" gpu_max="" gpu_boost=""
for path in /sys/class/drm/card*/gt_RPn_freq_mhz; do [[ -r "$path" ]] && { read -r gpu_min < "$path"; break; }; done
for path in /sys/class/drm/card*/gt_RP0_freq_mhz; do [[ -r "$path" ]] && { read -r gpu_max < "$path"; break; }; done
for path in /sys/class/drm/card*/gt_boost_freq_mhz; do [[ -r "$path" ]] && { read -r gpu_boost < "$path"; break; }; done

dmi_vendor=$(read_file /sys/class/dmi/id/sys_vendor unknown | tr '\n' ' ')
dmi_model=$(read_file /sys/class/dmi/id/product_name unknown | tr '\n' ' ')
ram_mib=$(awk '/^MemTotal:/ { print int($2 / 1024); exit }' /proc/meminfo 2>/dev/null || printf '0')
root_device=$(findmnt -n -o SOURCE / 2>/dev/null || printf 'unknown')
if [[ -d /sys/bus/thunderbolt/devices ]]; then
  thunderbolt_count=$(find /sys/bus/thunderbolt/devices -mindepth 1 -maxdepth 1 -type d | wc -l)
else
  thunderbolt_count=0
fi

nix_strings() {
  local item
  for item in "$@"; do printf '"%s" ' "$item"; done
}
gpu_nix="" profile_nix="" panel_nix="" mode_nix=""
if ((${#gpu_vendors[@]})); then gpu_nix=$(nix_strings "${gpu_vendors[@]}"); fi
if ((${#platform_profiles[@]})); then profile_nix=$(nix_strings "${platform_profiles[@]}"); fi
if ((${#panel_names[@]})); then panel_nix=$(nix_strings "${panel_names[@]}"); fi
if ((${#panel_modes[@]})); then mode_nix=$(nix_strings "${panel_modes[@]}"); fi

if [[ "$cpu_vendor" == intel && "$gpu_min" =~ ^[0-9]+$ && "$gpu_max" =~ ^[0-9]+$ && "$gpu_boost" =~ ^[0-9]+$ ]]; then
  gpu_freq_nix="{ min = $gpu_min; max = $gpu_max; boost = $gpu_boost; }"
else
  gpu_freq_nix="null"
fi

mkdir -p "$target"
mv "$tmp/hardware-configuration.nix" "$target/hardware-configuration.nix"
cat > "$target/system.nix" <<EOF
# Detected when generated: DMI=$dmi_vendor $dmi_model; CPU=$cpu_vendor ($cpu_driver);
# GPU vendors=[${gpu_nix}]; battery=$battery_name; platform profiles=[${profile_nix}];
# internal panels=[${panel_nix}]; panel modes=[${mode_nix}]; RAM=${ram_mib} MiB;
# root device=$root_device; Thunderbolt controllers=$thunderbolt_count.
# Recheck detected facts and add only this machine's hardware quirks below.
{ user, ... }:
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

  _module.args.hostFacts = {
    cpuVendor = "$cpu_vendor";
    gpuVendors = [ ${gpu_nix} ];
    hasBattery = $has_battery;
    batteryName = "$battery_name";
    chargeThresholds = null;
    platformProfileChoices = [ ${profile_nix} ];
    intelGpuBatteryFrequencies = $gpu_freq_nix;
  };

  networking.hostName = "$host_name";
  networking.networkmanager.enable = true;
  time.timeZone = user.timeZone;
  time.hardwareClockInLocalTime = user.hardwareClockInLocalTime;
  i18n.defaultLocale = user.locale;
  programs.hyprland.enable = true;
  programs.zsh.enable = true;
  hardware.graphics.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.11";
}
EOF

printf 'Created %s from detected host facts.\n' "$target"
printf 'CPU: %s (%s); GPU vendors: %s; battery: %s; platform profiles: %s\n' \
  "$cpu_vendor" "${cpu_driver:-unknown driver}" "${gpu_vendors[*]:-none}" "${battery_name:-none}" "${platform_profiles[*]:-none}"
printf 'DMI: %s %s; internal panels: %s; panel modes: %s; RAM: %s MiB; root: %s; Thunderbolt devices: %s\n' \
  "$dmi_vendor" "$dmi_model" "${panel_names[*]:-none}" "${panel_modes[*]:-none}" "$ram_mib" "$root_device" "$thunderbolt_count"
printf 'Review both generated files, then add them explicitly: git add %q %q\n' \
  "hosts/$host_dir_name/hardware-configuration.nix" "hosts/$host_dir_name/system.nix"
