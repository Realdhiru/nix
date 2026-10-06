{ pkgs, lib, ... }:
{
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 53 67 68 ]; # Allow DHCP & DNS for hotspot clients
  };

  security.apparmor.enable = true;

  # Rootless Podman container engine (daemonless, on-demand for Distrobox)
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };

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

  # KDE Connect completely disabled per user preference
  programs.kdeconnect.enable = false;

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

  # Userspace OOM guard: without this, RAM exhaustion (e.g. repack
  # decompressor + Electron app) thrashes into a hard freeze because the
  # 23GB swap keeps the kernel OOM killer from ever firing in time.
  # Mem-driven (swap threshold 100 = effectively memory-only): SIGTERM the
  # biggest hog below 5% available, SIGKILL if still critical. Selection is
  # by oom_score (RSS-heavy hogs); compositor/shell are small and never
  # picked in practice. (earlyoom 1.9.0 has no avoid/prefer flags.)
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 100;
  };

  # Removable drives & UDisks2 NTFS mount options (allows user ownership and dirty bit recovery)
  services.udisks2.enable = true;
  environment.etc."udisks2/mount_options.conf".text = ''
    [defaults]
    ntfs_defaults=uid=$UID,gid=$GID,rw
    ntfs_allow=uid=$UID,gid=$GID,umask,dmask,fmask,locale,norecover,nocase,windows_names,compression,nocompression,nocache,force,rw,remove_hiberfile
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
    ];
    config = {
      common = {
        default = [ "hyprland" "gtk" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
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

  # greetd console display manager with pure OLED minimal tuigreet
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --battery --remember --remember-session --width 64 --window-padding 2 --container-padding 2 --prompt-padding 1 --theme 'border=white;text=white;time=white;prompt=white;input=white;action=white;button=white;container=black' --cmd Hyprland";
        user = "greeter";
      };
    };
  };
  services.displayManager.defaultSession = "hyprland";
}