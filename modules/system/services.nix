{ pkgs, lib, ... }:
{
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 53 67 68 ]; # Allow DHCP & DNS for hotspot clients
  };

  security.apparmor.enable = true;

  # D-Bus implementation.
  services.dbus.implementation = "broker";

  # Journal size limit (prevents flush delays on boot)
  services.journald.settings.Journal = {
    SystemMaxUse = "100M";
    SystemMaxFileSize = "20M";
  };

  # Nix store maintenance.
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
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
    powerOnBoot = false;
  };
  services.blueman.enable = true;

  # File manager integration.
  services.gvfs.enable = true;

  # Flatpak application support & Flathub repository (runs asynchronously once network is online)
  services.flatpak.enable = true;
  systemd.services.flatpak-repo = {
    wantedBy = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if ! flatpak remotes --columns=name 2>/dev/null | grep -qx "flathub"; then
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
      fi
    '';
  };

  # Decouple local user sessions & display manager from network initialization
  systemd.services.systemd-user-sessions.after =
    lib.mkForce [ "remote-fs.target" "nss-user-lookup.target" ];

  # Printing.
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      epson-escpr
    ];
  };

  # Screen recording.
  programs.gpu-screen-recorder.enable = true;

  # KDE Connect (enables daemon + opens required firewall ports 1714-1764)
  programs.kdeconnect.enable = true;
  services.udev.packages = [ pkgs.kdePackages.kdeconnect-kde ];

  # Virtual input device support for KDE Connect digitizer / drawing tablet
  hardware.uinput.enable = true;
  services.udev.extraRules = ''
    KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0666", TAG+="uaccess", OPTIONS+="static_node=uinput"
  '';

  # Power management.
  services.upower = {
    enable = true;
    usePercentageForPolicy = true;
    percentageLow = 15;
    percentageCritical = 8;
    percentageAction = 3;
    criticalPowerAction = "Hibernate";
  };

  # Removable drives & UDisks2 NTFS mount options (allows user ownership and dirty bit recovery)
  services.udisks2.enable = true;
  environment.etc."udisks2/mount_options.conf".text = ''
    [defaults]
    ntfs_defaults=uid=$UID,gid=$GID
    ntfs_allow=uid=$UID,gid=$GID,umask,dmask,fmask,locale,norecover,ignore_case,windows_names,compression,nocompression,nocache,force
  '';

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

  services.logind = {
    settings.Login = {
      HandlePowerKey = "lock";
      HandleLidSwitch = "ignore";
    };
  };

  # Declarative Desktop Portal & Camera/Screen Sharing support
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      hypr-kdeconnect-portal
    ];
    config = {
      common = {
        default = [ "hyprland" "gtk" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.RemoteDesktop" = [ "hypr-kdeconnect" ];
      };
    };
  };

  # Hyprland session target (bound to graphical-session for Hyprland sessions only)
  systemd.user.targets.hyprland-session = {
    description = "Hyprland compositor session";
    documentation = [ "man:systemd.special(7)" ];
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    before = [ "graphical-session.target" ];
  };

  # Ly console display manager
  services.displayManager.ly = {
    enable = true;
    settings = {
      session_log = null;
    };
  };
  services.displayManager.defaultSession = "hyprland";

  # Virtual webcam loopback feeder: feeds stable native 1080p@5fps YUYV pass-through
  # into /dev/video10 for browsers/WebRTC on demand, bypassing Sonix MJPEG firmware crashes.
  # On-demand: Start with `cam-on` (or `systemctl --user start camera-loopback`)
  #            Stop with `cam-off` (or `systemctl --user stop camera-loopback`)
  systemd.user.services.camera-loopback = {
    description = "Webcam Pass-Through Loopback Feeder → /dev/video10";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    path = [ pkgs.ffmpeg pkgs.coreutils pkgs.bash ];

    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash %h/nix/dotfiles/hypr/scripts/camera-loopback.sh";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}