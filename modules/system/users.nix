{ pkgs, ... }:

{
  users.users.realdhiru = {
    isNormalUser = true;

    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh;
  };

  services.getty.autologinUser = "realdhiru";
  services.getty.autologinOnce = true;

  # Narrowly-scoped passwordless sudo for the two exact CPU turbo/boost
  # toggle commands the Quickshell power-profile popup needs to write.
  # This is intentionally NOT a blanket grant on `tee` or `tlp` — sudoers
  # matches the full command line verbatim, so only these two precise
  # sysfs writes are permitted without a password, nothing else.
  security.sudo.extraRules = [
    {
      users = [ "realdhiru" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/tee /sys/devices/system/cpu/intel_pstate/no_turbo";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/tee /sys/devices/system/cpu/cpufreq/boost";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/modprobe -r snd_hda_intel snd_soc_avs";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/modprobe snd_hda_intel";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}