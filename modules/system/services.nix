{ pkgs, ... }:

{
  #
  # Audio
  #
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  #
  # Bluetooth
  #
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = true;

  #
  # Thunar
  #
  programs.thunar = {
    enable = true;

plugins = with pkgs; [
  thunar-archive-plugin
  thunar-volman
];
  };

  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.xfconf.enable = true;

  #
  # Power
  #
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  #
  # Drives
  #
  services.udisks2.enable = true;

  #
  # Dconf
  #
  programs.dconf.enable = true;

  #
  # Polkit
  #
  security.polkit.enable = true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
             action.id == "org.freedesktop.udisks2.filesystem-mount-system") &&
            subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        }
    });
  '';

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";

    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "simple";

      ExecStart =
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";

      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };
}