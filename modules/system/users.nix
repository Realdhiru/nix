{ pkgs, user, ... }:

{
  users.users.${user.username} = {
    isNormalUser = true;
    description = user.name;
    home = user.homeDirectory;

    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "uinput"
      "ydotool"
    ];
    shell = pkgs.zsh;
  };



  # Passwordless audio recovery is restricted to these exact modprobe calls.
  # TLP profile privileges live beside the battery-aware TLP service in
  # modules/system/power.nix.
  security.sudo.extraRules = [
    {
      users = [ user.username ];
      commands = [
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
