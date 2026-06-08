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
}
