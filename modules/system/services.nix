{ pkgs, ... }:

{
  # D-Bus implementation.
  services.dbus.implementation = "broker";

  # Nix store maintenance.
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Audio.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  # Bluetooth.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # File manager integration.
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

    # Printing.
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      epson-escpr
    ];
  };

  # Screen recording.
  programs.gpu-screen-recorder.enable = true;

  # Power management.
  services.upower.enable = true;

  # Removable drives.
  services.udisks2.enable = true;

  # Desktop settings.
  programs.dconf.enable = true;

  # Authentication and mount permissions.
  security.polkit = {
    enable = true;

    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (
          (action.id == "org.freedesktop.udisks2.filesystem-mount" ||
           action.id == "org.freedesktop.udisks2.filesystem-mount-system") &&
          subject.isInGroup("wheel")
        ) {
          return polkit.Result.YES;
        }
      });
    '';
  };

  # Polkit authentication agent.
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