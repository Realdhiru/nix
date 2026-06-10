{ pkgs, ... }:

{
  programs.thunar.enable = true;

  services.gvfs.enable = true;      # Mount, Trash, network shares
  services.tumbler.enable = true;   # Image thumbnails
  programs.xfconf.enable = true;    # Preserve Thunar settings
  services.udisks2.enable = true;
  services.upower.enable = true;

  services.power-profiles-daemon.enable = true;

  security.polkit.enable = true;

  # Allow wheel users to mount drives without password
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
             action.id == "org.freedesktop.udisks2.filesystem-mount-system") &&
            subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        }
    });
  '';

  # Polkit agent
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";

    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };
}
