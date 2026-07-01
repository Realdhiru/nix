{ pkgs, ... }:

{ 
  # D-Bus IPC Optimization
  # Drop latency and make system events across Quickshell & Hyprland snappy
  services.dbus.implementation = "broker";

  # Nix Storage Optimization
  # Stop generations from clogging up your disk automatically
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Thunar
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

  # GPU Screen Recorder Wrapper
  # Configures proper setuid capabilities for gsr-kms-server to bypass root prompts
  programs.gpu-screen-recorder.enable = true;

  # Power
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  # Automate Power Profiles and Asus Fan Curves based on Charger Status
  services.udev.extraRules = ''
    # On AC Plug-in: Switch to Performance (Max Fan Curve, Max Power)
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance"
    
    # On Battery (Unplug): Switch to Balanced (Race to Idle, Best Battery/Heat Ratio)
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced"
  '';

  # Drives
  services.udisks2.enable = true;

  # Dconf
  programs.dconf.enable = true;

  # Polkit
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

  # Memory
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
}