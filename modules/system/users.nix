{ ... }:

{
  users.users.realdhiru = {
    isNormalUser = true;

    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  services.getty.autologinUser = "realdhiru";
}
