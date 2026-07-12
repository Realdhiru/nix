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

  # Narrowly-scoped passwordless sudo for the exact commands the Quickshell
  # power-profile/battery popup and audio-recovery script need to run as
  # root: two CPU turbo/boost sysfs writes, two audio-driver modprobe
  # commands, and the EPP-setting helper script. This is intentionally NOT
  # a blanket grant on `tee`, `modprobe`, or `tlp` — sudoers matches the
  # full command line verbatim for the first four, so only those precise
  # invocations are permitted without a password, nothing else.
  #
  # The set_epp.sh rule is the one exception: its argument is left
  # unpinned because the script writes to a shell-glob-expanded set of
  # per-core sysfs files (glob expansion happens before sudo is invoked,
  # so the fully-expanded argument list isn't stable across machines/core
  # counts and can't be matched verbatim in sudoers). Instead, set_epp.sh
  # itself whitelists the EPP value before writing anything — the script
  # is the security boundary here, not the sudoers argument match.
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
        {
          command = "/home/realdhiru/.config/hypr/scripts/quickshell/battery/set_epp.sh";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}